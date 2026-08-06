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
          baseline_content_hash: compute_content_hash
        )
        # Emit event (handled by outbox — Wave 3)
        # cityos.helm.strategy.baseline-requested.v1
      end

      # Apply a verified DWOS approval projection.
      # The projection MUST be validated before calling this method.
      def apply_verified_baseline!(approval_projection:, sync_identity:)
        validate_approval_projection!(approval_projection)

        transaction do
          # Create immutable snapshot
          StrategySnapshot.create!(
            plan_id: id,
            version: version,
            content_hash: compute_content_hash,
            snapshot_type: :baseline,
            metadata: { approval_ref: approval_projection[:ref], approved_by: approval_projection[:approved_by] }
          )

          update!(
            status: :active,
            version: version + 1,
            baseline_status: :approved,
            approval_ref: approval_projection[:ref],
            approval_source_revision: approval_projection[:source_revision],
            approval_subject_hash: approval_projection[:subject_hash],
            approval_projected_at: Time.current
          )
        end
        # Emit event (handled by outbox — Wave 3)
        # cityos.helm.strategy.baselined.v1
      end

      def approval_projected?
        approval_ref.present? && baseline_approved?
      end

      private

      def validate_approval_projection!(projection)
        raise ArgumentError, "missing approval_ref" if projection[:ref].blank?
        raise ArgumentError, "missing subject_hash" if projection[:subject_hash].blank?
        raise ArgumentError, "content hash mismatch" unless projection[:subject_hash] == compute_content_hash
        raise ArgumentError, "version mismatch" unless projection[:version] == version
        raise ArgumentError, "revoked approval" if projection[:revoked]
      end

      def compute_content_hash
        Digest::SHA256.hexdigest(attributes.slice("title", "description", "plan_type", "scoring_config").to_s)
      end
    end
  end
end
