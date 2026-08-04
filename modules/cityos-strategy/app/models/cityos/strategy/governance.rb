# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class StrategicBenefit < ActiveRecord::Base
      self.table_name = "cityos_strategy_benefits"

      enum :benefit_type, {
        financial: 0, citizen: 1, operational: 2,
        platform: 3, regulatory: 4, strategic: 5
      }
      enum :status, {
        proposed: 0, planned: 1, tracking: 2,
        realized: 3, sustained: 4, not_realized: 5
      }, prefix: :status

      belongs_to :initiative, class_name: "StrategicInitiative"
      belongs_to :benefit_owner, class_name: "User", optional: true

      validates :target, presence: true

      def realization_percent
        return nil unless baseline && target && current_value
        range = target - baseline
        return 100.0 if range.zero?
        [((current_value - baseline) / range * 100).round(1), 100.0].min
      end
    end

    class StrategicRisk < ActiveRecord::Base
      self.table_name = "cityos_strategy_risks"

      enum :likelihood, { rare: 0, unlikely: 1, possible: 2, likely: 3, almost_certain: 4 }, prefix: true
      enum :impact, { negligible: 0, minor: 1, moderate: 2, major: 3, severe: 4 }, prefix: true
      enum :status, { active: 0, mitigated: 1, materialized: 2, closed: 3 }, prefix: :status

      belongs_to :initiative, class_name: "StrategicInitiative", optional: true
      belongs_to :objective, class_name: "StrategicObjective", optional: true

      validates :description, presence: true

      def risk_score
        StrategicRisk.likelihoods[likelihood] * StrategicRisk.impacts[impact]
      end
    end

    class StrategicAssumption < ActiveRecord::Base
      self.table_name = "cityos_strategy_assumptions"

      enum :status, { unvalidated: 0, valid: 1, invalidated: 2 }, prefix: :status

      belongs_to :initiative, class_name: "StrategicInitiative", optional: true
      belongs_to :objective, class_name: "StrategicObjective", optional: true

      validates :description, presence: true
    end

    class StrategicDependency < ActiveRecord::Base
      self.table_name = "cityos_strategy_dependencies"

      enum :dependency_type, { requires: 0, enables: 1, conflicts_with: 2, supersedes: 3 }, prefix: true
      enum :status, { identified: 0, active: 1, resolved: 2, broken: 3 }, prefix: true

      belongs_to :from_initiative, class_name: "StrategicInitiative"
      belongs_to :to_initiative, class_name: "StrategicInitiative"

      validates :from_initiative_id, uniqueness: { scope: %i[to_initiative_id dependency_type] }
    end

    class StrategicDecision < ActiveRecord::Base
      self.table_name = "cityos_strategy_decisions"

      enum :status, { proposed: 0, decided: 1, implemented: 2, superseded: 3 }, prefix: true

      belongs_to :decision_owner, class_name: "User", optional: true

      validates :title, presence: true
    end

    class StrategyReview < ActiveRecord::Base
      self.table_name = "cityos_strategy_reviews"

      enum :review_type, { qbr: 0, mbr: 1, annual: 2, event_driven: 3 }, prefix: true
      enum :status, { scheduled: 0, in_progress: 1, completed: 2, cancelled: 3 }, prefix: true

      belongs_to :facilitator, class_name: "User", optional: true
      belongs_to :plan, class_name: "StrategicPlan", optional: true
      has_many :snapshots, class_name: "StrategySnapshot"

      validates :period_start, :period_end, presence: true
    end

    class StrategySnapshot < ActiveRecord::Base
      self.table_name = "cityos_strategy_snapshots"

      enum :snapshot_type, {
        objective: 0, metric: 1, initiative: 2, benefit: 3, full_portfolio: 4
      }

      belongs_to :review, class_name: "StrategyReview"

      validates :frozen_state, presence: true
      validates :content_hash, presence: true

      before_validation :compute_hash, on: :create

      private

      def compute_hash
        self.content_hash = Digest::SHA256.hexdigest(frozen_state.to_json) if frozen_state.present?
      end
    end
  end
end
