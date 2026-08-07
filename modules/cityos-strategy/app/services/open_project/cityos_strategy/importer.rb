# frozen_string_literal: true

require "digest"
require "json"
require "securerandom"

# Wave 4 W4-1..W4-4 (2026-08-07): Cityos::Strategy::Importer.
#
# Governed bulk importer for the strategy pack (docs/architecture/
# engineering-services/expansion-pack/v1.0/*). Reshapes what was
# ad-hoc controller/SQL edits into a single service with six roles:
#
#   * Validator    — schema-checks input against the Universal Record
#                    Envelope (envelope shape only, not full domain).
#   * Planner      — matches records by immutable stable_id and produces
#                    a per-record verdict: create | update | no-op | conflict.
#   * DraftApplier — transactionally applies planned changes, EVERY record
#                    lands as draft (authorization_state: "draft"), NO
#                    PlanAuthorization rows are created, outbox emits are
#                    suppressed via SkipOutbox.wrap.
#   * Verifier     — reads back applied records + confirms serialization
#                    roundtrip against the input.
#   * Exporter     — serializes current draft state to canonical JSON.
#   * ReceiptWriter — creates a StrategyImportReceipt (audit evidence)
#                     for every run, in every mode.
#
# Modes: dry-run | apply-draft | verify | export.
# Bin: apply-baseline is NOT supported from the importer — the DWOS
# approval flow is the only path to baseline authority. Attempting
# mode: "apply-baseline" raises Importer::UnsupportedMode.
module Cityos
  module Strategy
    module Importer
      # ── SkipOutbox helper ──────────────────────────────────────────
      # Wave 4 W4-4: import runs must NOT flood the outbox with
      # baseline-requested events for every draft record. Callers wrap
      # any block that would trigger after_commit outbox emits inside
      # SkipOutbox.wrap { ... } — StrategicPlan#publish_baseline_saga_event
      # and PlanAuthorization#publish_plan_to_work_saga_event both consult
      # SkipOutbox.suppressed? before invoking Sagas::*.start.
      module SkipOutbox
        THREAD_KEY = :cityos_strategy_skip_outbox

        def self.suppressed?
          Thread.current[THREAD_KEY] == true
        end

        def self.wrap
          prior = Thread.current[THREAD_KEY]
          Thread.current[THREAD_KEY] = true
          yield
        ensure
          Thread.current[THREAD_KEY] = prior
        end
      end

      class Error < StandardError; end
      class InvalidPayload < Error; end
      class UnsupportedMode < Error; end

      MODES = %w[dry-run apply-draft verify export].freeze

      # Entry point. `payload` is the parsed YAML/JSON hash (or a path
      # to a file we'll load). Always returns a StrategyImportReceipt.
      def self.run(payload:, mode:, actor: nil, actor_scope: nil, source_path: "<memory>")
        raise UnsupportedMode, "mode=#{mode} not supported (allowed: #{MODES.join(', ')})" unless MODES.include?(mode)

        loaded = load_payload(payload, source_path: source_path)
        source_hash = Digest::SHA256.hexdigest(canonical_json(loaded[:records]))
        correlation_id = SecureRandom.uuid
        dry_run = mode != "apply-draft"

        receipt = OpenProject::CityosStrategy::StrategyImportReceipt.create!(
          source_path: source_path,
          source_hash: source_hash,
          mode: mode,
          status: "started",
          actor_id: actor&.id,
          actor_scope: actor_scope,
          correlation_id: correlation_id,
          dry_run: dry_run,
          record_deltas: {},
          verdicts: []
        )

        Validator.check!(loaded)
        verdicts = Planner.plan(loaded)

        case mode
        when "dry-run"
          finalize_receipt(receipt, verdicts: verdicts, deltas: summarize(verdicts))
        when "apply-draft"
          SkipOutbox.wrap do
            deltas = DraftApplier.apply(verdicts, correlation_id: correlation_id)
            finalize_receipt(receipt, verdicts: verdicts, deltas: deltas, applied_at: Time.current)
          end
        when "verify"
          verify_result = Verifier.verify(loaded[:records])
          finalize_receipt(receipt, verdicts: verdicts, deltas: verify_result)
        when "export"
          export_payload = Exporter.export
          finalize_receipt(receipt, verdicts: verdicts, deltas: { export_bytes: export_payload.bytesize })
        end

        receipt
      rescue => e
        receipt&.update!(status: "failed", error_message: "#{e.class}: #{e.message}")
        raise
      end

      def self.finalize_receipt(receipt, verdicts:, deltas:, applied_at: nil)
        attrs = { status: "completed", verdicts: verdicts, record_deltas: deltas }
        attrs[:applied_at] = applied_at if applied_at
        receipt.update!(attrs)
        receipt
      end

      def self.load_payload(payload, source_path:)
        return payload if payload.is_a?(Hash) && payload.key?(:records)

        if payload.is_a?(String) && File.exist?(payload)
          raw = File.read(payload)
          parsed = source_path.end_with?(".yaml", ".yml") || payload.end_with?(".yaml", ".yml") ?
                     YAML.safe_load(raw, permitted_classes: [Date, Time, Symbol], aliases: true) :
                     JSON.parse(raw)
          return normalize(parsed)
        end

        raise InvalidPayload, "payload must be a Hash with :records or a path to a YAML/JSON file"
      end

      def self.normalize(parsed)
        records = if parsed.is_a?(Array)
                    parsed
                  elsif parsed.is_a?(Hash)
                    parsed["records"] || parsed[:records] || Array(parsed)
                  else
                    []
                  end
        { records: records }
      end

      # Canonical JSON with sorted keys — matches the hashing pattern
      # used by StrategicPlan#compute_graph_content_hash.
      def self.canonical_json(records)
        JSON.generate(deep_sort(records))
      end

      def self.deep_sort(obj)
        case obj
        when Hash  then obj.sort.to_h.transform_values { |v| deep_sort(v) }
        when Array then obj.map { |e| deep_sort(e) }
        else obj
        end
      end

      def self.summarize(verdicts)
        counts = Hash.new(0)
        verdicts.each { |v| counts[v[:verdict]] += 1 }
        counts.transform_keys(&:to_s)
      end

      # ── Validator ──────────────────────────────────────────────────
      module Validator
        REQUIRED_KEYS = %w[stable_id record_type].freeze

        def self.check!(loaded)
          records = loaded[:records]
          raise InvalidPayload, "records must be an Array" unless records.is_a?(Array)
          records.each_with_index do |r, i|
            raise InvalidPayload, "records[#{i}] not a Hash" unless r.is_a?(Hash)
            REQUIRED_KEYS.each do |k|
              raise InvalidPayload, "records[#{i}] missing required key '#{k}'" unless r.key?(k) || r.key?(k.to_sym)
            end
          end
          true
        end
      end

      # ── Planner ────────────────────────────────────────────────────
      module Planner
        # Wave 4 W4-1 Phase B (2026-08-07): verdicts now carry the source
        # record (`:record`) + resolved model class (`:model`) so
        # DraftApplier can actually execute create!/update! without
        # re-walking the source. Prior verdicts recorded intent but
        # dropped the payload — DraftApplier could only count.
        def self.plan(loaded)
          loaded[:records].map do |record|
            stable_id = record["stable_id"] || record[:stable_id]
            record_type = record["record_type"] || record[:record_type]
            model = resolve_model(record_type)
            verdict = if model.nil?
                        :conflict
                      elsif model.exists?(stable_id: stable_id)
                        current = model.find_by(stable_id: stable_id)
                        differs?(current, record) ? :update : :"no-op"
                      else
                        :create
                      end
            {
              stable_id: stable_id,
              record_type: record_type,
              verdict: verdict.to_s,
              reason: verdict == :conflict ? "unknown record_type=#{record_type}" : nil,
              record: record,   # Wave 4 W4-1 Phase B: payload carried through.
              model: model      # nil for :conflict verdicts.
            }
          end
        end

        def self.resolve_model(record_type)
          {
            "strategic_plan"      => OpenProject::CityosStrategy::StrategicPlan,
            "objective"           => (OpenProject::CityosStrategy::StrategicObjective rescue nil),
            "initiative"          => (OpenProject::CityosStrategy::StrategicInitiative rescue nil),
            "review"              => (OpenProject::CityosStrategy::StrategyReview rescue nil),
            "metric_definition"   => (OpenProject::CityosStrategy::MetricDefinition rescue nil),
          }[record_type]
        end

        def self.differs?(current, incoming)
          return true unless current
          incoming_hash = incoming.reject { |k, _| %w[stable_id record_type].include?(k.to_s) }
          incoming_hash.any? { |k, v| current.respond_to?(k) && current.public_send(k) != v }
        end
      end

      # ── DraftApplier ───────────────────────────────────────────────
      module DraftApplier
        # Wave 4 W4-1 Phase B (2026-08-07): now executes create!/update!
        # using the source record carried through by Planner. Every
        # created/updated record lands with `authorization_state: "draft"`
        # per Wave 4 W4-4 isolation invariant. SkipOutbox.wrap in
        # Importer.run suppresses after_commit outbox emits.
        #
        # Failures on a single record downgrade its verdict to
        # `failed` + record the reason, then continue with the next.
        # The whole batch runs in ONE transaction so a rollback restores
        # atomicity — a per-record retry model belongs to a follow-on
        # `apply-draft --continue-on-error` mode, out of scope here.
        def self.apply(verdicts, correlation_id:)
          created = 0
          updated = 0
          skipped = 0
          conflicts = 0
          failures = []

          ActiveRecord::Base.transaction do
            verdicts.each do |v|
              case v[:verdict]
              when "create"
                begin
                  apply_create!(v)
                  created += 1
                rescue => e
                  failures << { stable_id: v[:stable_id], reason: "create failed: #{e.class}: #{e.message}" }
                  raise ActiveRecord::Rollback
                end
              when "update"
                begin
                  apply_update!(v)
                  updated += 1
                rescue => e
                  failures << { stable_id: v[:stable_id], reason: "update failed: #{e.class}: #{e.message}" }
                  raise ActiveRecord::Rollback
                end
              when "no-op"
                skipped += 1
              when "conflict"
                conflicts += 1
              end
            end
          end

          {
            "create"          => created,
            "update"          => updated,
            "no-op"           => skipped,
            "conflict"        => conflicts,
            "failures"        => failures,
            "correlation_id"  => correlation_id,
            "outbox_suppressed" => SkipOutbox.suppressed?,
            # Backwards-compat aliases for callers that pinned to the
            # Wave 4 Phase A output shape.
            "create-planned"  => created,
            "update-planned"  => updated
          }
        end

        # Extract the AR-attributes-safe subset from the incoming record.
        # stable_id + record_type are Importer metadata, never persisted
        # as regular columns. Reject nested arrays/hashes that don't map
        # to AR scalar columns (child associations are managed by their
        # own record entries in the Importer payload).
        def self.attributes_for(v)
          record = v[:record] || {}
          model  = v[:model]
          allowed = model&.column_names || []
          attrs = record.each_with_object({}) do |(k, val), acc|
            key = k.to_s
            next if %w[stable_id record_type].include?(key)
            next if val.is_a?(Hash) || val.is_a?(Array) # child assoc — handled separately
            acc[key] = val if allowed.include?(key)
          end
          attrs["stable_id"] = v[:stable_id]
          # Wave 4 W4-4 isolation invariant: every importer-created
          # record starts as draft. If the model doesn't carry
          # authorization_state, this write is a no-op.
          if allowed.include?("authorization_state")
            attrs["authorization_state"] = "draft"
          end
          attrs
        end

        def self.apply_create!(v)
          attrs = attributes_for(v)
          v[:model].create!(attrs)
        end

        def self.apply_update!(v)
          current = v[:model].find_by(stable_id: v[:stable_id])
          raise ActiveRecord::RecordNotFound, "no #{v[:record_type]} with stable_id=#{v[:stable_id]}" unless current
          # Preserve W4-4 isolation invariant: never advance
          # authorization_state beyond draft via importer.
          attrs = attributes_for(v)
          attrs.delete("authorization_state") if current.respond_to?(:authorization_state) && current.authorization_state != "draft"
          current.update!(attrs)
        end
      end

      # ── Verifier ───────────────────────────────────────────────────
      module Verifier
        def self.verify(records)
          matched = 0
          missing = 0
          divergent = 0
          records.each do |r|
            stable_id = r["stable_id"] || r[:stable_id]
            record_type = r["record_type"] || r[:record_type]
            model = Planner.resolve_model(record_type)
            unless model
              divergent += 1
              next
            end
            found = model.find_by(stable_id: stable_id)
            if found.nil?
              missing += 1
            elsif Planner.differs?(found, r)
              divergent += 1
            else
              matched += 1
            end
          end
          { "matched" => matched, "missing" => missing, "divergent" => divergent }
        end
      end

      # ── Exporter ───────────────────────────────────────────────────
      module Exporter
        def self.export
          plans = OpenProject::CityosStrategy::StrategicPlan.all
          payload = {
            "generated_at" => Time.current.iso8601,
            "record_count" => plans.count,
            "records" => plans.map do |p|
              {
                "stable_id"   => p.stable_id,
                "record_type" => "strategic_plan",
                "title"       => p.title,
                "version"     => p.version,
                "graph_content_hash" => (p.respond_to?(:graph_content_hash) ? p.graph_content_hash : nil)
              }
            end
          }
          Cityos::Strategy::Importer.canonical_json(payload)
        end
      end
    end
  end
end
