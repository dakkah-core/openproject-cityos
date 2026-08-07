# frozen_string_literal: true

# HEXP-0301/0302: Event Outbox Service + Event Catalog
# Provides transactional outbox writes and canonical event subject definitions.
module OpenProject
  module CityosStrategy
    class EventOutboxService
      # ── HELM publishes these events ────────────────────────────────
      HELM_EVENTS = {
        "baseline-requested" => "cityos.helm.strategy.baseline-requested.v1",
        "baselined"          => "cityos.helm.strategy.baselined.v1",
        "superseded"         => "cityos.helm.strategy.superseded.v1",
        "objective-changed"  => "cityos.helm.objective.changed.v1",
        "target-changed"     => "cityos.helm.target.changed.v1",
        "initiative-submitted"  => "cityos.helm.initiative.submitted.v1",
        "initiative-selected"   => "cityos.helm.initiative.selected.v1",
        "initiative-activated"  => "cityos.helm.initiative.activated.v1",
        "scenario-review-requested" => "cityos.helm.scenario.review-requested.v1",
        "scenario-frozen"     => "cityos.helm.scenario.frozen.v1",
        "plan-authorized"     => "cityos.helm.plan.authorized-for-execution.v1",
        "review-completed"    => "cityos.helm.review.completed.v1",
        "release-candidate-created" => "cityos.helm.release-candidate.created.v1",
        "benefit-review-due"  => "cityos.helm.benefit.review-due.v1"
      }.freeze

      # ── HELM consumes these events ─────────────────────────────────
      INBOX_EVENTS = {
        "dwos.approval.created"   => "cityos.dwos.approval.created.v1",
        "dwos.approval.revoked"   => "cityos.dwos.approval.revoked.v1",
        "psee.specification.changed" => "cityos.psee.specification.changed.v1",
        "psee.impact.detected"    => "cityos.psee.impact.detected.v1",
        "pedd.violation.detected" => "cityos.pedd.violation.detected.v1",
        "pedd.evaluation.completed" => "cityos.pedd.evaluation.completed.v1",
        "workcontrol.work.accepted"  => "cityos.workcontrol.work.accepted.v1",
        "workcontrol.evidence.submitted" => "cityos.workcontrol.evidence.submitted.v1",
        "assurance.evidence.accepted" => "cityos.assurance.evidence.accepted.v1",
        "assurance.evidence.invalidated" => "cityos.assurance.evidence.invalidated.v1",
        "ucl.gate.evaluated"      => "cityos.ucl.gate.evaluated.v1",
        "ucl.lifecycle.transitioned" => "cityos.ucl.lifecycle.transitioned.v1",
        "extension.activation.activated" => "cityos.extension.activation.activated.v1",
        "docs.document.reconciled" => "cityos.docs.document.reconciled.v1",
        "psee.decision.proposed"  => "cityos.psee.decision.proposed.v1"
      }.freeze

      # Write an event to the transactional outbox.
      # MUST be called inside an ActiveRecord transaction with the business write.
      def self.publish!(aggregate:, event_name:, payload:, correlation_id: nil, causation_id: nil)
        event_type = HELM_EVENTS[event_name]
        raise ArgumentError, "unknown event: #{event_name}" unless event_type

        record = StrategyEventOutbox.create!(
          event_id: SecureRandom.uuid,
          event_type: event_type,
          event_subject: event_type,
          aggregate_type: aggregate.class.name.demodulize,
          aggregate_id: aggregate.try(:stable_id) || aggregate.id.to_s,
          payload: payload,
          metadata: {
            correlation_id: correlation_id || SecureRandom.uuid,
            causation_id: causation_id,
            source_revision: resolve_source_revision,
            tenant_id: resolve_tenant_id,
            created_by: User.current&.id
          },
          correlation_id: correlation_id,
          causation_id: causation_id,
          source_revision: resolve_source_revision,
          tenant_id: resolve_tenant_id,
          schema_version: "cityos.event.v1"
        )

        record
      end

      # HEXP-0308: Drain the outbox (publish to NATS JetStream)
      # Called by the background publisher worker.
      def self.drain_outbox!(batch_size: 50)
        records = StrategyEventOutbox.where(publish_status: :pending)
                                     .order(:created_at)
                                     .limit(batch_size)

        records.each do |record|
          publish_to_nats(record)
        rescue => e
          record.update!(publish_status: :failed, publish_error: e.message, publish_attempts: record.publish_attempts + 1)
        end
      end

      # HEXP-0308: Move to DLQ after max retries
      def self.move_to_dlq!(record)
        record.update!(publish_status: :dlq)
      end

      private

      # Wave 3 W3-4 (2026-08-07): real NATS JetStream publish via
      # the `nats-pure` gem (pure-Ruby client, no C extension).
      #
      # Design:
      #   * Subject convention: cityos.helm.<event_name>.v1  (matches
      #     config/engineering-services/event-subject.registry.json).
      #   * We build the payload envelope (event_id, occurred_at,
      #     correlation_id, tenant_id, source_revision) so downstream
      #     consumers get consistent metadata regardless of publisher.
      #   * The `nats-pure` gem is a soft dependency: if it's missing
      #     at runtime we mark the record as :failed with a clear
      #     error message rather than crashing the drainer. This lets
      #     an operator see the state, install the gem, and resume.
      #   * A single NATS connection is memoized per Rails process
      #     (@nats_client). The drainer runs every 5s, so tearing down
      #     the connection per publish would be wasteful.
      def self.publish_to_nats(record)
        require "nats/io/client"

        subject = "cityos.helm.#{record.event_name.tr('-', '.')}.v1"
        envelope = {
          event_id: record.event_id,
          event_name: record.event_name,
          occurred_at: record.created_at.iso8601,
          correlation_id: record.correlation_id,
          causation_id: record.causation_id,
          tenant_id: record.tenant_id,
          source_revision: record.source_revision,
          payload: record.payload_json
        }.to_json

        js = jetstream_client
        js.publish(subject, envelope, timeout: 5)
        record.update!(publish_status: :published, published_at: Time.current)
      rescue LoadError => e
        # nats-pure not installed — leave record pending, log once.
        Rails.logger.error("[helm-outbox] nats-pure gem missing; add `gem 'nats-pure'` and bundle install to enable JetStream publish. record=#{record.event_id}")
        record.update!(publish_status: :failed, publish_error: "nats-pure gem not installed: #{e.message}", publish_attempts: record.publish_attempts + 1)
      end

      # Memoized NATS JetStream client. First call opens the
      # connection; subsequent calls return the cached client. If the
      # underlying connection has closed, we reopen.
      def self.jetstream_client
        if @nats_client && @nats_client.connected?
          return @nats_client.jetstream
        end
        nats_url = ENV.fetch("HELM_NATS_URL", "nats://127.0.0.1:4222")
        @nats_client = NATS::IO::Client.new
        @nats_client.connect(servers: [nats_url])
        @nats_client.jetstream
      end

      def self.resolve_source_revision
        ENV.fetch("CITYOS_SOURCE_REVISION", "development")
      end

      def self.resolve_tenant_id
        Thread.current[:cityos_tenant_id] || "default"
      end
    end

    # ── Event Outbox Model ──────────────────────────────────────────
    class StrategyEventOutbox < ActiveRecord::Base
      self.table_name = "cityos_strategy_event_outbox"

      enum :publish_status, {
        pending: "pending",
        published: "published",
        failed: "failed",
        dlq: "dlq",
        skipped: "skipped"
      }, prefix: :publish_status

      validates :event_id, presence: true, uniqueness: true
      validates :event_type, presence: true
      validates :aggregate_type, presence: true

      scope :drainable, -> { where(publish_status: :pending).order(:created_at) }
    end
  end
end
