# frozen_string_literal: true

class CreateCityosStrategyPlans < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_plans do |t|
      t.string :title, null: false
      t.text :description

      # Plan classification
      t.integer :plan_type, null: false, default: 0
      # enum: vision(0), strategic(1), annual(2), operating(3)

      t.integer :status, null: false, default: 0
      # enum: draft(0), active(1), superseded(2), archived(3)

      t.date :effective_from
      t.date :effective_to

      # Ownership and hierarchy
      t.references :owner, foreign_key: { to_table: :users }
      t.references :parent_plan, foreign_key: { to_table: :cityos_strategy_plans }

      # Versioning and governance
      t.integer :version, null: false, default: 1
      t.string :document_ref
      t.string :approval_ref
      t.datetime :approval_verified_at

      # Scoring configuration (JSONB for per-cycle customization)
      t.jsonb :scoring_config, default: {
        alignment: 0.25,
        value: 0.20,
        citizen_value: 0.10,
        regulatory_urgency: 0.10,
        risk_reduction: 0.10,
        platform_leverage: 0.10,
        capability_readiness: 0.05,
        time_to_value: 0.05,
        evidence_confidence: 0.05
      }

      t.timestamps
    end

    add_index :cityos_strategy_plans, :plan_type
    add_index :cityos_strategy_plans, :status
    add_index :cityos_strategy_plans, :approval_ref
  end
end
