# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class StrategicInitiative < ActiveRecord::Base
      self.table_name = "cityos_strategy_initiatives"

      FUNNEL_STAGES = {
        idea: 0, screened: 1, candidate: 2, evidence_gathering: 3,
        evaluated: 4, prioritized: 5, scenario_selected: 6,
        funding_pending: 7, approval_pending: 8, activated: 9,
        benefits_review: 10, closed: 11, stopped: 12, superseded: 13
      }.freeze

      enum :stage, FUNNEL_STAGES, prefix: :stage
      enum :mandatory_class, { mandatory: 0, regulatory: 1, committed: 2, scored: 3 }, prefix: true
      enum :funding_status, { unfunded: 0, requested: 1, approved: 2, allocated: 3, spent: 4 }, prefix: :funding
      enum :decision_status, { pending: 0, recommended: 1, deferred: 2, rejected: 3, activated: 4 }, prefix: :decision

      belongs_to :portfolio, class_name: "StrategicPortfolio", optional: true
      belongs_to :scenario, class_name: "PlanningScenario", optional: true
      belongs_to :owner, class_name: "User", optional: true
      has_many :initiative_objectives, class_name: "InitiativeObjective"
      has_many :objectives, through: :initiative_objectives
      has_many :benefits, class_name: "StrategicBenefit"
      has_many :risks, class_name: "StrategicRisk"
      has_many :execution_links, class_name: "ExecutionLink"

      validates :initiative_id, presence: true, uniqueness: true
      validates :title, presence: true

      scope :bypass_scoring, -> { where(mandatory_class: %i[mandatory regulatory]) }
      scope :scorable, -> { where(mandatory_class: %i[committed scored]) }
      scope :active, -> { where(stage: %i[activated benefits_review]) }

      def bypass_scoring?
        mandatory? || regulatory?
      end

      def advance_stage!(target_stage)
        target_idx = FUNNEL_STAGES[target_stage.to_sym]
        current_idx = FUNNEL_STAGES[stage.to_sym]
        raise ArgumentError, "Cannot move backwards: #{stage} -> #{target_stage}" if target_idx <= current_idx

        update!(stage: target_stage)
      end
    end

    class InitiativeObjective < ActiveRecord::Base
      self.table_name = "cityos_strategy_initiative_objectives"
      belongs_to :initiative, class_name: "StrategicInitiative"
      belongs_to :objective, class_name: "StrategicObjective"
      validates :initiative_id, uniqueness: { scope: :objective_id }
    end

    class StrategicPortfolio < ActiveRecord::Base
      self.table_name = "cityos_strategy_portfolios"
      enum :status, { active: 0, archived: 1 }
      belongs_to :owner, class_name: "User", optional: true
      has_many :programs, class_name: "StrategicProgram"
      has_many :initiatives, class_name: "StrategicInitiative"
      validates :name, presence: true
    end

    class StrategicProgram < ActiveRecord::Base
      self.table_name = "cityos_strategy_programs"
      enum :status, { active: 0, archived: 1 }
      belongs_to :portfolio, class_name: "StrategicPortfolio"
      belongs_to :owner, class_name: "User", optional: true
      has_many :initiatives, through: :portfolio
      validates :name, presence: true
    end

    class ExecutionLink < ActiveRecord::Base
      self.table_name = "cityos_strategy_execution_links"
      enum :link_type, { delivers: 0, supports: 1, tracks: 2 }
      belongs_to :strategic_initiative, class_name: "StrategicInitiative"
      belongs_to :work_package
      validates :strategic_initiative_id, uniqueness: { scope: :work_package_id }
    end
  end
end
