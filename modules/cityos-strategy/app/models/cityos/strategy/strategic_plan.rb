# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class StrategicPlan < ApplicationRecord
      self.table_name = "cityos_strategy_plans"

      enum :plan_type, { vision: 0, strategic: 1, annual: 2, operating: 3 }
      enum :status, { draft: 0, active: 1, superseded: 2, archived: 3 }

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

      def baseline!
        update!(status: :active, version: version + 1, approval_verified_at: Time.current)
      end

      def approval_projected?
        approval_ref.present? && approval_verified_at.present?
      end
    end
  end
end
