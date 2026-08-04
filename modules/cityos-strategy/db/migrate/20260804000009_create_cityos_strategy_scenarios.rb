# frozen_string_literal: true

class CreateCityosStrategyScenarios < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_scenarios do |t|
      t.string :scenario_id, null: false
      t.string :planning_cycle, null: false
      t.string :name, null: false
      t.text :assumptions
      t.integer :status, null: false, default: 0
      t.integer :version, null: false, default: 1
      t.decimal :funding_allocation, precision: 15, scale: 2
      t.text :capacity_allocation
      t.text :constraint_violations
      t.integer :recommendation_status, default: 0
      t.timestamps
    end
    add_index :cityos_strategy_scenarios, :scenario_id, unique: true
  end
end
