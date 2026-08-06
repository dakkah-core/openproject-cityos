# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class CoverageTarget < ActiveRecord::Base
      self.table_name = "cityos_strategy_coverage_targets"

      DIMENSIONS = %w[functional technical operational compliance].freeze
      POLICIES = %w[manual automated inferred].freeze

      belongs_to :objective, class_name: "StrategicObjective", optional: true

      validates :target_id, presence: true, uniqueness: true
      validates :universe_node, presence: true
      validates :coverage_dimension, presence: true, inclusion: { in: DIMENSIONS }
      validates :measurement_policy, inclusion: { in: POLICIES }

      before_validation :generate_target_id, on: :create

      def achieved?
        current_pct.to_f >= target_pct.to_f
      end

      def gap
        [(target_pct.to_f - current_pct.to_f), 0].max
      end

      private

      def generate_target_id
        self.target_id ||= "covt-#{SecureRandom.uuid}"
      end
    end
  end
end
