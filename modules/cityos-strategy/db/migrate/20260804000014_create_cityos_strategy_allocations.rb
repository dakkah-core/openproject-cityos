# frozen_string_literal: true

class CreateCityosStrategyAllocations < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_allocations do |t|
      t.references :scenario, null: false, foreign_key: { to_table: :cityos_strategy_scenarios }
      t.references :initiative, null: false, foreign_key: { to_table: :cityos_strategy_initiatives }
      t.integer :dimension, null: false, default: 0
      t.decimal :amount, precision: 15, scale: 2
      t.string :unit
      t.timestamps
    end
  end
end
