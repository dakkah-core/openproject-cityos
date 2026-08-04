# frozen_string_literal: true

class CreateCityosStrategyMetricObservations < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_metric_observations do |t|
      t.references :metric_definition, null: false, foreign_key: { to_table: :cityos_strategy_metric_definitions }
      t.references :target, foreign_key: { to_table: :cityos_strategy_metric_targets }
      t.decimal :value, precision: 15, scale: 4, null: false
      t.datetime :observed_at, null: false
      t.string :source_system
      t.string :source_metric_id
      t.integer :freshness, null: false, default: 0
      t.integer :confidence, default: 1
      t.integer :quality_state, null: false, default: 0
      t.string :evidence_ref
      t.timestamps
    end
    add_index :cityos_strategy_metric_observations, %i[metric_definition_id observed_at],
              name: "idx_metric_obs_def_time"
  end
end
