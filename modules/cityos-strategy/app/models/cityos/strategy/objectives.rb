# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class StrategicTheme < ActiveRecord::Base
      self.table_name = "cityos_strategy_themes"
      belongs_to :plan, class_name: "StrategicPlan"
      has_many :objectives, class_name: "StrategicObjective", foreign_key: :theme_id
      validates :name, presence: true
    end

    class StrategicOutcome < ActiveRecord::Base
      self.table_name = "cityos_strategy_outcomes"
      belongs_to :plan, class_name: "StrategicPlan"
      has_many :objectives, class_name: "StrategicObjective", foreign_key: :outcome_id
      validates :name, presence: true
    end

    class StrategicObjective < ActiveRecord::Base
      self.table_name = "cityos_strategy_objectives"

      enum :status, { draft: 0, active: 1, at_risk: 2, behind: 3, achieved: 4, closed: 5 }
      enum :health, { on_track: 0, at_risk: 1, off_track: 2, unknown: 3 }

      belongs_to :plan, class_name: "StrategicPlan"
      belongs_to :theme, class_name: "StrategicTheme", optional: true
      belongs_to :outcome, class_name: "StrategicOutcome", optional: true
      belongs_to :parent_objective, class_name: "StrategicObjective", optional: true
      belongs_to :owner, class_name: "User", optional: true
      has_many :child_objectives, class_name: "StrategicObjective", foreign_key: :parent_objective_id
      has_many :key_results, class_name: "KeyResult"
      has_many :initiative_objectives, class_name: "InitiativeObjective"
      has_many :initiatives, through: :initiative_objectives

      validates :objective_id, presence: true, uniqueness: true
      validates :title, presence: true

      def compute_health!
        kr_healths = key_results.pluck(:status)
        if kr_healths.empty?
          update!(health: :unknown)
        elsif kr_healths.all? { |s| s == "on_track" }
          update!(health: :on_track)
        elsif kr_healths.any? { |s| %w[at_risk off_track].include?(s) }
          update!(health: :off_track)
        else
          update!(health: :at_risk)
        end
      end
    end

    class KeyResult < ActiveRecord::Base
      self.table_name = "cityos_strategy_key_results"

      enum :status, { not_started: 0, on_track: 1, at_risk: 2, behind: 3, completed: 4 }
      enum :confidence, { low: 0, medium: 1, high: 2 }

      belongs_to :objective, class_name: "StrategicObjective"
      validates :title, presence: true
      validates :target_value, presence: true

      def progress_percent
        return nil unless baseline_value && target_value && current_value
        range = target_value - baseline_value
        return 100.0 if range.zero?
        [((current_value - baseline_value) / range * 100).round(1), 100.0].min
      end
    end
  end
end
