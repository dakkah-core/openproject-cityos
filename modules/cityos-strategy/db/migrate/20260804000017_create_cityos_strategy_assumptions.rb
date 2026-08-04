# frozen_string_literal: true

class CreateCityosStrategyAssumptions < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_assumptions do |t|
      t.text :description, null: false
      t.date :valid_until
      t.text :validation_criteria
      t.integer :status, null: false, default: 0
      t.references :initiative, foreign_key: { to_table: :cityos_strategy_initiatives }
      t.references :objective, foreign_key: { to_table: :cityos_strategy_objectives }
      t.timestamps
    end
  end
end
