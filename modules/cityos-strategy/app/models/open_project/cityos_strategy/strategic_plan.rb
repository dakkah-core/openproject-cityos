# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class StrategicPlan < ActiveRecord::Base
      self.table_name = "cityos_strategy_plans"

      enum :plan_type, { vision: 0, strategic: 1, annual: 2, operating: 3 }, prefix: true
      enum :status, { draft: 0, review_pending: 1, approval_pending: 2, active: 3, superseded: 4, archived: 5 }, prefix: true
      enum :baseline_status, { not_requested: 0, pending: 1, rejected: 2, approved: 3, revoked: 4 }, prefix: :baseline

      belongs_to :owner, class_name: "User", optional: true
      belongs_to :parent_plan, class_name: "StrategicPlan", optional: true
      has_many :child_plans, class_name: "StrategicPlan", foreign_key: :parent_plan_id
      has_many :themes, class_name: "StrategicTheme"
      has_many :outcomes, class_name: "StrategicOutcome"
      has_many :objectives, class_name: "StrategicObjective"
  has_many :plan_authorizations, class_name: "PlanAuthorization"

      # Chain: Plan → Objectives → Initiatives → Execution
      has_many :initiative_objectives, through: :objectives
      has_many :initiatives, through: :objectives

      # Plan → Benefits via initiative chain
      has_many :benefits, through: :initiatives

      # Plan → Execution links via initiative chain
      has_many :execution_links, through: :initiatives

      # Plan → Reviews (QBR/MBR/Annual)
      has_many :reviews, class_name: "StrategyReview"

      # Plan → Metrics (scoped to this plan)
      has_many :metric_definitions, class_name: "MetricDefinition"

      # Plan → Allocations via initiatives → scenarios
      has_many :allocations, through: :initiatives

      validates :title, presence: true
      validates :version, presence: true, numericality: { only_integer: true, greater_than: 0 }
      validates :stable_id, uniqueness: true, allow_nil: true  # HEXP-0104

      before_create :generate_stable_id  # HEXP-0104

      # Wave 3 W3-3 (2026-08-07): after_commit outbox wiring.
      # Fires the BaselineSaga when the plan's authoritative content
      # actually changes on the DB (baseline_status flips to :pending,
      # or graph_content_hash moves). We use after_commit not after_save
      # so the outbox write only happens for rows that actually persisted.
      after_commit :publish_baseline_saga_event, on: [:create, :update], if: :baseline_content_changed_for_outbox?

      # HEXP-0104: Auto-generate stable cross-system identity
      def generate_stable_id
        self.stable_id ||= "helm-plan-#{SecureRandom.uuid}"
      end

      # ── HEXP-0101: Authority correction ────────────────────────────
      # HELM must NEVER create or infer approval.
      # Only DWOS governance_approvals rows are authority.

      # Request baseline — creates a pending DWOS decision request.
      # Does NOT change status, version, or write any approval field.
      def request_baseline!(actor:, correlation_id:)
        update!(
          baseline_status: :pending,
          baseline_requested_at: Time.current,
          baseline_requested_by: actor.id,
          baseline_content_hash: compute_content_hash,
          graph_content_hash: compute_graph_content_hash
        )
        # Emit event (handled by outbox — Wave 3)
        # cityos.helm.strategy.baseline-requested.v1
      end

      # Apply a verified DWOS approval projection.
      # The projection MUST be validated before calling this method.
      def apply_verified_baseline!(approval_projection:, sync_identity:)
        validate_approval_projection!(approval_projection)

        transaction do
          # Create immutable snapshot — Wave 2 W2-5 stores the full-graph
          # hash so anyone comparing the snapshot against the approval
          # can detect child-record drift too.
          graph_hash = compute_graph_content_hash
          StrategySnapshot.create!(
            plan_id: id,
            version: version,
            content_hash: graph_hash,
            snapshot_type: :baseline,
            metadata: {
              approval_ref: approval_projection[:ref],
              approved_by: approval_projection[:approved_by],
              plan_only_content_hash: compute_content_hash,
              graph_content_hash: graph_hash
            }
          )

          update!(
            status: :active,
            version: version + 1,
            baseline_status: :approved,
            approval_ref: approval_projection[:ref],
            approval_source_revision: approval_projection[:source_revision],
            approval_subject_hash: approval_projection[:subject_hash],
            approval_projected_at: Time.current,
            graph_content_hash: graph_hash
          )
        end
        # Emit event (handled by outbox — Wave 3)
        # cityos.helm.strategy.baselined.v1
      end

      def approval_projected?
        approval_ref.present? && baseline_approved?
      end

      # ── Wave 2 W2-5: full-graph canonical hash ─────────────────────
      #
      # Serializes the plan + all 16 child associations via
      # ActiveRecord's as_json (sorted keys via canonical_json_dump) and
      # SHA-256 hashes the canonical text. A mutation to ANY child
      # (theme, outcome, objective, key_result, initiative binding,
      # benefit, risk, execution_link, review, snapshot, metric target,
      # observation, scenario, allocation, plan authorization) changes
      # this hash — the prior 4-column plan-only hash did not.
      #
      # Backward compat: the old `compute_content_hash` name is preserved
      # below as an alias for the plan-only 4-column serialization so
      # any legacy caller still gets the old behavior. New code should
      # call `compute_graph_content_hash`.
      def compute_graph_content_hash
        graph = build_graph_snapshot
        Digest::SHA256.hexdigest(canonical_json_dump(graph))
      end

      private

      def validate_approval_projection!(projection)
        raise ArgumentError, "missing approval_ref" if projection[:ref].blank?
        raise ArgumentError, "missing subject_hash" if projection[:subject_hash].blank?
        raise ArgumentError, "content hash mismatch" unless projection[:subject_hash] == compute_graph_content_hash
        raise ArgumentError, "version mismatch" unless projection[:version] == version
        raise ArgumentError, "revoked approval" if projection[:revoked]
      end

      # Legacy 4-column plan-only hash — retained under the original name
      # so any existing consumer still gets the exact old bytes. New
      # authority-binding code MUST use compute_graph_content_hash.
      def compute_content_hash
        Digest::SHA256.hexdigest(attributes.slice("title", "description", "plan_type", "scoring_config").to_s)
      end

      # Deterministic JSON serializer with keys sorted at every level.
      # Two graphs with the same values in different key order produce
      # identical bytes.
      def canonical_json_dump(value)
        case value
        when Hash
          "{" + value.keys.map(&:to_s).sort.map { |k|
            k.to_json + ":" + canonical_json_dump(value[k.to_sym].nil? ? value[k] : value[k.to_sym])
          }.join(",") + "}"
        when Array
          "[" + value.map { |v| canonical_json_dump(v) }.join(",") + "]"
        else
          value.to_json
        end
      end

      def build_graph_snapshot
        {
          plan: attributes.slice("title", "description", "plan_type", "scoring_config", "version"),
          themes: themes.order(:id).pluck(:id, :name),
          outcomes: outcomes.order(:id).pluck(:id, :name),
          objectives: objectives.order(:id).map { |o|
            {
              id: o.id,
              title: o.title,
              status: o.try(:status),
              key_results: o.key_results.order(:id).pluck(:id, :title, :target_value, :current_value),
            }
          },
          initiatives: initiatives.order(:id).map { |i|
            {
              id: i.id,
              title: i.title,
              stage: i.try(:stage),
              bindings: safe_pluck(i, :engineering_service_bindings, %i[id engineering_service_id role status]),
              benefits: safe_pluck(i, :benefits, %i[id name quantified_value]),
              risks: safe_pluck(i, :risks, %i[id title severity]),
              execution_links: safe_pluck(i, :execution_links, %i[id work_package_id]),
              globalization_bindings: safe_pluck(i, :globalization_bindings, %i[id country_cell]),
            }
          },
          reviews: reviews.order(:id).map { |r|
            {
              id: r.id,
              review_type: r.try(:review_type),
              snapshots: safe_pluck(r, :snapshots, %i[id content_hash snapshot_type]),
            }
          },
          metric_definitions: metric_definitions.order(:id).map { |m|
            {
              id: m.id,
              name: m.name,
              targets: safe_pluck(m, :targets, %i[id target_value target_date]),
              observations: safe_pluck(m, :observations, %i[id value observed_at]),
            }
          },
          allocations: allocations.order(:id).pluck(:id, :amount, :allocation_type),
          plan_authorizations: plan_authorizations.order(:id).pluck(:id, :authorization_state, :plan_hash, :dwos_approval_ref),
        }
      end

      # Some Rails associations may not exist on every environment or
      # migration state. Rather than crash the hash, fall back to an
      # empty array and record the association name in a special key so
      # the hash still reflects "we tried and it wasn't there".
      def safe_pluck(record, association, columns)
        return [] unless record.respond_to?(association)
        rel = record.public_send(association)
        return [] unless rel.respond_to?(:pluck)
        rel.order(:id).pluck(*columns)
      rescue ActiveRecord::StatementInvalid, NoMethodError
        [{ _unavailable: association.to_s }]
      end

      # Wave 3 W3-3: outbox trigger predicate.
      # True when the plan has just been created OR when a save moved
      # baseline_status/graph_content_hash — i.e. the plan's "authorized
      # material" changed. Silences chatty saves (touch, non-graph
      # attribute updates) so we don't flood the outbox.
      def baseline_content_changed_for_outbox?
        saved_change_to_id? ||
          saved_change_to_baseline_status? ||
          saved_change_to_graph_content_hash? ||
          saved_change_to_baseline_content_hash?
      end

      # Wave 3 W3-3: publish BaselineSaga start via the transactional
      # outbox. The Sagas::BaselineSaga.start method is the ONLY path
      # that writes to the outbox from a plan-level change.
      #
      # actor resolution: User.current works during a controller action
      # (OpenProject sets it in ApplicationController). In background/
      # console contexts it may be nil — the saga handles that by
      # emitting actor_id=nil, which downstream consumers treat as
      # "system" (audited but not attributed to a human).
      def publish_baseline_saga_event
        # Wave 4 W4-4: importer runs suppress outbox emits so bulk imports
        # don't flood downstream services with baseline-requested events
        # for every draft record. When Cityos::Strategy::Importer::SkipOutbox
        # is active, we short-circuit here and rely on the receipt row
        # for audit trail instead.
        if defined?(Cityos::Strategy::Importer::SkipOutbox) && Cityos::Strategy::Importer::SkipOutbox.suppressed?
          return
        end

        actor = User.respond_to?(:current) ? User.current : nil
        # System actor fallback so the saga signature always resolves.
        actor ||= OpenStruct.new(id: nil)
        correlation_id = SecureRandom.uuid
        Sagas::BaselineSaga.start(plan: self, actor: actor, correlation_id: correlation_id)
      rescue => e
        # Never let outbox write failures break the plan save. Log and
        # continue — the drainer will pick up any successful outbox rows
        # separately, and monitoring should watch for missing baseline
        # events for plans whose baseline_status transitioned.
        Rails.logger.error("[helm-plan-outbox] BaselineSaga.start failed for plan=#{id} stable_id=#{stable_id}: #{e.class}: #{e.message}")
      end
    end
  end
end
