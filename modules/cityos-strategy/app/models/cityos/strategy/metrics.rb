# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class MetricDefinition < ::ApplicationRecord
      self.table_name = "cityos_strategy_metric_definitions"

      enum :direction, { higher_better: 0, lower_better: 1, target_range: 2 }
      enum :aggregation, { sum: 0, avg: 1, min: 2, max: 3, last: 4 }
      enum :frequency, { daily: 0, weekly: 1, monthly: 2, quarterly: 3, annual: 4 }
      enum :framework_profile, {
        okr: 0, balanced_scorecard: 1, ogsm: 2, hoshin: 3,
        government: 4, cityos_engineering: 5
      }

      belongs_to :owner, class_name: "User", optional: true
      belongs_to :plan, class_name: "StrategicPlan", optional: true
      has_many :targets, class_name: "MetricTarget"
      has_many :observations, class_name: "MetricObservation"

      validates :metric_id, presence: true, uniqueness: true
      validates :name, presence: true

      def latest_observation
        observations.order(observed_at: :desc).first
      end

      def freshness_status
        obs = latest_observation
        return "no_data" unless obs
        return obs.freshness
      end
    end

    class MetricTarget < ::ApplicationRecord
      self.table_name = "cityos_strategy_metric_targets"
      belongs_to :metric_definition, class_name: "MetricDefinition"
      belongs_to :owner, class_name: "User", optional: true
      has_many :observations, class_name: "MetricObservation", foreign_key: :target_id
      validates :target, presence: true
      validates :period_start, :period_end, presence: true
    end

    class MetricObservation < ::ApplicationRecord
      self.table_name = "cityos_strategy_metric_observations"

      enum :freshness, { current: 0, stale: 1, expired: 2 }
      enum :confidence, { low: 0, medium: 1, high: 2 }
      enum :quality_state, { verified: 0, estimated: 1, projected: 2, disputed: 3 }

      belongs_to :metric_definition, class_name: "MetricDefinition"
      belongs_to :target, class_name: "MetricTarget", optional: true

      validates :value, presence: true
      validates :observed_at, presence: true

      scope :recent, -> { where(freshness: :current).order(observed_at: :desc) }
    end

    class PlanningScenario < ::ApplicationRecord
      self.table_name = "cityos_strategy_scenarios"

      enum :status, { draft: 0, frozen: 1, accepted: 2, rejected: 3 }
      enum :recommendation_status, {
        recommended: 0, not_recommended: 1, needs_revision: 2, rejected: 3
      }

      has_many :initiatives, class_name: "StrategicInitiative", foreign_key: :scenario_id
      has_many :allocations, class_name: "StrategicAllocation"

      validates :scenario_id, presence: true, uniqueness: true
      validates :name, presence: true

      def freeze!
        update!(status: :frozen, version: version + 1)
      end

      def unfreeze!
        raise "Cannot unfreeze accepted scenario" if accepted?
        update!(status: :draft)
      end
    end

    class StrategicAllocation < ::ApplicationRecord
      self.table_name = "cityos_strategy_allocations"

      DIMENSIONS = {
        funding: 0, labor: 1, supplier: 2, skills: 3,
        infra: 4, ai_budget: 5, env: 6, ops_change: 7, regulatory_review: 8
      }.freeze

      enum :dimension, DIMENSIONS

      belongs_to :scenario, class_name: "PlanningScenario"
      belongs_to :initiative, class_name: "StrategicInitiative"
    end
  end
end
