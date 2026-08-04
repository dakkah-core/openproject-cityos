# frozen_string_literal: true

class CreateCityosStrategyThemes < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_themes do |t|
      t.string :name, null: false
      t.text :description
      t.references :plan, null: false, foreign_key: { to_table: :cityos_strategy_plans }
      t.integer :position, null: false, default: 0
      t.string :color

      t.timestamps
    end
  end
end
