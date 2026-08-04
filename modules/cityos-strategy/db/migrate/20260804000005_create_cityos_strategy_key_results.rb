# frozen_string_literal: true

class CreateCityosStrategyKeyResults < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_key_results do |t|
      t.references :objective, null: false, foreign_key: { to_table: :cityos_strategy_objectives }
      t.string :title, null: false
      t.decimal :baseline_value, precision: 15, scale: 4
      t.decimal :target_value, precision: 15, scale: 4
      t.decimal :current_value, precision: 15, scale: 4
      t.string :unit
      t.date :target_date
      t.integer :status, null: false, default: 0
      t.integer :confidence, default: 0
      t.timestamps
    end
    add_index :cityos_strategy_key_results, :status
  end
end
