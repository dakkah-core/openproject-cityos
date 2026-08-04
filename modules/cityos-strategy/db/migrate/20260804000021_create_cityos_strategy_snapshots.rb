# frozen_string_literal: true

class CreateCityosStrategySnapshots < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_snapshots do |t|
      t.references :review, null: false, foreign_key: { to_table: :cityos_strategy_reviews }
      t.integer :snapshot_type, null: false, default: 0
      t.string :entity_type, null: false
      t.integer :entity_id, null: false
      t.jsonb :frozen_state, null: false, default: {}
      t.string :content_hash
      t.timestamps
    end
    add_index :cityos_strategy_snapshots, %i[entity_type entity_id],
              name: "idx_snapshot_entity"
    add_index :cityos_strategy_snapshots, :content_hash
  end
end
