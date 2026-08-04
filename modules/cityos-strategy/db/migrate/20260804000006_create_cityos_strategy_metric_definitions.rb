# frozen_string_literal: true

class CreateCityosStrategyMetricDefinitions < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_metric_definitions do |t|
      t.string :metric_id, null: false
      t.string :name, null: false
      t.text :description
      t.text :formula
      t.string :unit
      t.integer :direction, null: false, default: 0
      t.integer :aggregation, default: 4
      t.integer :frequency, null: false, default: 2
      t.string :source_system
      t.integer :framework_profile, default: 0
      t.references :owner, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :cityos_strategy_metric_definitions, :metric_id, unique: true
  end
end
