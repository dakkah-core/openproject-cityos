# frozen_string_literal: true

# Connects reviews and metrics to strategic plans for complete chain integrity.
# StrategicPlan → reviews → snapshots
# StrategicPlan → metric_definitions → targets → observations

class AddPlanReferencesForCompleteChain < ActiveRecord::Migration[7.1]
  def change
    # Reviews scoped to a plan
    add_reference :cityos_strategy_reviews, :plan,
                  foreign_key: { to_table: :cityos_strategy_plans },
                  null: true # nullable for backward compat

    # Metrics scoped to a plan (optional — metrics can be global)
    add_reference :cityos_strategy_metric_definitions, :plan,
                  foreign_key: { to_table: :cityos_strategy_plans },
                  null: true
  end
end
