# frozen_string_literal: true

class CreateCityosStrategyInitiatives < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_initiatives do |t|
      t.string :initiative_id, null: false
      t.string :title, null: false
      t.text :description
      t.integer :stage, null: false, default: 0
      t.integer :mandatory_class, null: false, default: 3
      t.decimal :alignment_score, precision: 4, scale: 1
      t.decimal :value_score, precision: 4, scale: 1
      t.decimal :urgency_score, precision: 4, scale: 1
      t.decimal :risk_score, precision: 4, scale: 1
      t.decimal :readiness_score, precision: 4, scale: 1
      t.decimal :effort_score, precision: 4, scale: 1
      t.decimal :evidence_confidence, precision: 4, scale: 1
      t.decimal :weighted_score, precision: 4, scale: 1
      t.decimal :estimated_cost, precision: 15, scale: 2
      t.text :capacity_demand
      t.integer :funding_status, default: 0
      t.integer :decision_status, default: 0
      t.references :portfolio, foreign_key: { to_table: :cityos_strategy_portfolios }
      t.references :scenario, foreign_key: { to_table: :cityos_strategy_scenarios }
      t.references :owner, foreign_key: { to_table: :users }
      t.string :approval_ref
      t.datetime :approval_verified_at
      t.timestamps
    end
    add_index :cityos_strategy_initiatives, :initiative_id, unique: true
    add_index :cityos_strategy_initiatives, :stage
  end
end
