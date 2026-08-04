# frozen_string_literal: true

class CreateCityosStrategyObjectives < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_objectives do |t|
      t.string :objective_id, null: false
      t.string :title, null: false
      t.text :description
      t.references :plan, null: false, foreign_key: { to_table: :cityos_strategy_plans }
      t.references :theme, foreign_key: { to_table: :cityos_strategy_themes }
      t.references :outcome, foreign_key: { to_table: :cityos_strategy_outcomes }
      t.references :parent_objective, foreign_key: { to_table: :cityos_strategy_objectives }
      t.references :owner, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.integer :health, default: 0
      t.timestamps
    end
    add_index :cityos_strategy_objectives, :objective_id, unique: true
  end
end
