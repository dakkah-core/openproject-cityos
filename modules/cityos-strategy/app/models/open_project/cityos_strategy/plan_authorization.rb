# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class PlanAuthorization < ActiveRecord::Base
      self.table_name = 'cityos_strategy_plan_authorizations'

      STATES = %w[draft approved executing completed revoked].freeze

      belongs_to :plan, class_name: 'StrategicPlan', optional: true
      belongs_to :authorized_by, class_name: 'User', optional: true

      validates :authorization_id, presence: true, uniqueness: true
      validates :plan_version, presence: true
      validates :plan_hash, presence: true
      validates :source_revision, presence: true
      validates :dwos_approval_ref, presence: true
      validates :authorization_state, inclusion: { in: STATES }

      before_validation :generate_authorization_id, on: :create
      after_save :publish_to_bridge, if: :authorization_state_changed_to_approved?

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

      def authorization_state_changed_to_approved?
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
    end
  end
end
