# frozen_string_literal: true

class CreateCityosStrategyFeedbackSignals < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_feedback_signals do |t|
      t.string :signal_id, null: false
      t.string :source, null: false
      t.string :metric_ref
      t.datetime :observation_time, null: false
      t.jsonb :observation_data, null: false, default: {}
      t.decimal :quality_score, precision: 3, scale: 2, default: 1.0
      t.interval :freshness
      t.string :affected_objectives, array: true, default: []
      t.string :affected_initiatives, array: true, default: []
      t.text :recommendation
      t.string :human_disposition, default: 'pending'
      t.references :dispositioned_by, foreign_key: { to_table: :users }
      t.datetime :dispositioned_at
      t.timestamps
    end

    add_index :cityos_strategy_feedback_signals, :signal_id, unique: true
    add_index :cityos_strategy_feedback_signals, :source
    add_index :cityos_strategy_feedback_signals, :human_disposition
  end
end
