# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class CoreContributionProfile < ActiveRecord::Base
      self.table_name = "cityos_strategy_core_contribution_profiles"

      CONTRIBUTION_LEVELS = %w[required supporting projection-only external not-applicable].freeze

      validates :profile_id, presence: true, uniqueness: true
      validates :scope_node_id, presence: true
      validates :cms_contribution, inclusion: { in: CONTRIBUTION_LEVELS }
      validates :agora_contribution, inclusion: { in: CONTRIBUTION_LEVELS }
      validates :nexus_contribution, inclusion: { in: CONTRIBUTION_LEVELS }
      validates :tryton_contribution, inclusion: { in: CONTRIBUTION_LEVELS }

      before_validation :generate_profile_id, on: :create

      private

      def generate_profile_id
        self.profile_id ||= "ccp-#{SecureRandom.uuid}"
      end
    end
  end
end
