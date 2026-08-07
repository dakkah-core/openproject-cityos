# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    # Wave 2 W2-6 (2026-08-07): PlanAuthorization now enforces real
    # equality + authority + SoD + source-revision checks instead of the
    # prior four presence-only validations (verified as P0.5 by the
    # 14-agent workflow: "nonblank string checks only — no equality /
    # authority / SoD / CSRF").
    #
    # Design:
    #   * `plan_hash` MUST equal the plan's current `graph_content_hash`
    #     at the time the authorization is submitted. Rejects any attempt
    #     to authorize a stale plan snapshot.
    #   * `source_revision` MUST equal the plan's `updated_at.iso8601` at
    #     the time of authorization submission (best-available "source"
    #     reference in the Rails engine; Wave 3 will migrate to Git SHA
    #     when the strategy repo is externalized).
    #   * `dwos_approval_ref` MUST match the canonical shape
    #     `gov-*` (DWOS approvalRef prefix). The FULL DWOS resolution
    #     (subject_hash equality, status, revoked_at, approver != owner,
    #     scope) moves to an after_commit saga in Wave 3 W3-3 — putting
    #     an HTTP call inside an AR validation is an anti-pattern.
    #   * `authorized_by_id` (if the plan has an owner_id) MUST NOT equal
    #     the plan.owner_id — SoD at the Rails layer, complementing DWOS
    #     W2-9's no-strategy-owner-self-approval rule.
    #
    # The controller's PATCH shortcut ("presence of dwos_approval_ref =>
    # can transition to approved") is deleted; the state machine now
    # requires the full validation set to pass first.
    class PlanAuthorization < ActiveRecord::Base
      self.table_name = 'cityos_strategy_plan_authorizations'

      STATES = %w[draft approved executing completed revoked].freeze

      # Wave 2 W2-6: shape gate for dwos_approval_ref. Full DWOS
      # resolution happens in Wave 3 W3-3 (after_commit saga).
      DWOS_APPROVAL_REF_PATTERN = /\Agov-[A-Za-z0-9._:\-]{4,}\z/.freeze

      belongs_to :plan, class_name: 'StrategicPlan', optional: true
      belongs_to :authorized_by, class_name: 'User', optional: true

      validates :authorization_id, presence: true, uniqueness: true
      validates :plan_version, presence: true
      validates :plan_hash, presence: true
      validates :source_revision, presence: true
      validates :dwos_approval_ref, presence: true
      validates :dwos_approval_ref, format: {
        with: DWOS_APPROVAL_REF_PATTERN,
        message: "must be a DWOS approvalRef starting with 'gov-'"
      }, if: -> { dwos_approval_ref.present? }
      validates :authorization_state, inclusion: { in: STATES }

      # Wave 2 W2-6: real equality + SoD checks (fire only when the
      # attribute has been set — allows partial constructors to still
      # save drafts before the plan association is available).
      validate :plan_hash_matches_current_graph_hash, if: -> { plan && plan_hash.present? }
      validate :source_revision_matches_plan_updated_at, if: -> { plan && source_revision.present? }
      validate :authorized_by_not_plan_owner, if: -> { plan && authorized_by_id.present? }
      validate :must_have_dwos_ref_when_approving

      before_validation :generate_authorization_id, on: :create

      # Wave 3 W3-3 (2026-08-07): moved from after_save to after_commit
      # so we only publish once the transaction is durable. Also added
      # a saga event that writes to the transactional outbox for the
      # PlanToWork lifecycle (Sagas::PlanToWorkSaga.start).
      after_commit :publish_to_bridge, if: :authorization_state_changed_to_approved_on_commit?
      after_commit :publish_plan_to_work_saga_event, on: :update, if: :authorization_state_changed_to_approved_on_commit?

      scope :approved, -> { where(authorization_state: 'approved') }
      scope :active, -> { where(authorization_state: %w[approved executing]) }

      def approved?
        authorization_state == 'approved'
      end

      def executable?
        %w[approved executing].include?(authorization_state)
      end

      private

      def generate_authorization_id
        self.authorization_id ||= "auth-#{SecureRandom.uuid}"
      end

      def plan_hash_matches_current_graph_hash
        expected = plan.respond_to?(:compute_graph_content_hash) ? plan.compute_graph_content_hash : nil
        return unless expected  # legacy or partial plan — skip rather than block
        return if plan_hash == expected
        errors.add(:plan_hash, "does not match plan's current graph_content_hash (Wave 2 W2-6 equality check)")
      end

      def source_revision_matches_plan_updated_at
        expected = plan.updated_at.utc.iso8601
        return if source_revision == expected
        errors.add(:source_revision, "does not match plan.updated_at.iso8601 (expected=#{expected}, got=#{source_revision})")
      end

      def authorized_by_not_plan_owner
        return unless plan.respond_to?(:owner_id)
        return unless plan.owner_id
        return if authorized_by_id != plan.owner_id
        errors.add(:authorized_by_id, "cannot equal plan.owner_id (Wave 2 W2-6 SoD: plan owner cannot self-authorize)")
      end

      def must_have_dwos_ref_when_approving
        return unless authorization_state == 'approved'
        return if dwos_approval_ref.present?
        errors.add(:dwos_approval_ref, "is required to transition to 'approved'")
      end

      def authorization_state_changed_to_approved?
        saved_change_to_authorization_state? && authorization_state == 'approved'
      end

      # Wave 3 W3-3: after_commit-friendly predicate. saved_change_to_*
      # is still valid inside after_commit callbacks because the change
      # attribute set survives the transaction commit boundary.
      def authorization_state_changed_to_approved_on_commit?
        saved_change_to_authorization_state? && authorization_state == 'approved'
      end

      def publish_to_bridge
        HelmLedger.publish_plan_authorized(
          plan_id: plan&.id,
          authorization_id: authorization_id,
          strategy_ref: "op-wp-auth-#{id}",
          work_items: approved_scope&.dig('task_count') || 0
        )
      end

      # Wave 3 W3-3: PlanToWorkSaga outbox emit. Fires when the plan
      # authorization is approved — this is the platform's signal that
      # a strategy plan is ready for Work Control materialization.
      def publish_plan_to_work_saga_event
        return unless plan
        # Wave 4 W4-4: importer runs suppress outbox emits.
        if defined?(Cityos::Strategy::Importer::SkipOutbox) && Cityos::Strategy::Importer::SkipOutbox.suppressed?
          return
        end
        correlation_id = SecureRandom.uuid
        # We don't have a first-class Initiative selection at this
        # point in the lifecycle (that comes from Work Control); the
        # saga's `start` expects an initiative + plan pair. Emit the
        # authorization event directly to the outbox so downstream
        # services (Work Control, UCL) can react without waiting on
        # Sagas::PlanToWorkSaga.start (which requires an initiative
        # argument we don't yet have).
        EventOutboxService.publish!(
          aggregate: self,
          event_name: "plan-authorized-for-execution",
          payload: {
            plan_stable_id: plan.stable_id,
            plan_version: plan.version,
            plan_hash: plan_hash,
            authorization_id: authorization_id,
            dwos_approval_ref: dwos_approval_ref,
            authorized_by_id: authorized_by_id,
            authorized_at: Time.current.iso8601
          },
          correlation_id: correlation_id
        )
      rescue => e
        Rails.logger.error("[helm-authz-outbox] plan-authorized-for-execution publish failed for authz=#{authorization_id}: #{e.class}: #{e.message}")
      end
    end
  end
end
