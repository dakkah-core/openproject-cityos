# frozen_string_literal: true

class CreateCityosStrategyRisks < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_risks do |t|
      t.references :initiative, foreign_key: { to_table: :cityos_strategy_initiatives }
      t.references :objective, foreign_key: { to_table: :cityos_strategy_objectives }
      t.text :description, null: false
      t.integer :likelihood, null: false, default: 0
      t.integer :impact, null: false, default: 0
      t.text :mitigation
      t.integer :status, null: false, default: 0
      t.timestamps
    end
  end
end
