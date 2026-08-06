# frozen_string_literal: true

class CreateCityosStrategyCoverageBaselines < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_coverage_baselines do |t|
      t.string :baseline_id, null: false
      t.integer :version, null: false, default: 1
      t.string :universe_version, null: false
      t.string :included_node_set, array: true, default: []
      t.string :node_set_hash, null: false
      t.string :approval_ref
      t.date :effective_from
      t.date :effective_until
      t.string :superseded_by
      t.references :owner, foreign_key: { to_table: :users }
      t.jsonb :snapshot_data, default: {}
      t.timestamps
    end

    add_index :cityos_strategy_coverage_baselines, :baseline_id, unique: true
    add_index :cityos_strategy_coverage_baselines, :version
    add_index :cityos_strategy_coverage_baselines, :approval_ref

    create_table :cityos_strategy_coverage_targets do |t|
      t.string :target_id, null: false
      t.references :objective, foreign_key: { to_table: :cityos_strategy_objectives }
      t.string :universe_node, null: false
      t.string :coverage_dimension, null: false
      t.string :baseline_id
      t.decimal :target_pct, precision: 5, scale: 1, default: 100.0
      t.decimal :current_pct, precision: 5, scale: 1, default: 0.0
      t.date :target_date
      t.string :source_metric
      t.string :measurement_policy, default: 'manual'
      t.timestamps
    end

    add_index :cityos_strategy_coverage_targets, :target_id, unique: true
    add_index :cityos_strategy_coverage_targets, :baseline_id
    add_index :cityos_strategy_coverage_targets, :universe_node
  end
end
