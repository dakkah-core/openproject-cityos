# frozen_string_literal: true

class CreateCityosStrategyMetricTargets < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_metric_targets do |t|
      t.references :metric_definition, null: false, foreign_key: { to_table: :cityos_strategy_metric_definitions }
      t.decimal :baseline, precision: 15, scale: 4
      t.decimal :target, precision: 15, scale: 4, null: false
      t.decimal :floor, precision: 15, scale: 4
      t.decimal :ceiling, precision: 15, scale: 4
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.references :owner, foreign_key: { to_table: :users }
      t.timestamps
    end
  end
end
