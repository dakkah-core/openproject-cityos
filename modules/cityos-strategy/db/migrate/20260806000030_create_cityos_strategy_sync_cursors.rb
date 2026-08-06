# frozen_string_literal: true

class CreateCityosStrategySyncCursors < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_sync_cursors do |t|
      t.string :cursor_id, null: false
      t.string :peer_service, null: false
      t.string :stream_name, null: false
      t.string :last_cursor_value
      t.string :last_source_version
      t.string :before_hash
      t.string :after_hash
      t.string :conflict_state, default: 'clean'
      t.string :last_sync_result
      t.string :idempotency_key
      t.string :correlation_id
      t.datetime :synced_at
      t.timestamps
    end

    add_index :cityos_strategy_sync_cursors, :cursor_id, unique: true
    add_index :cityos_strategy_sync_cursors, %i[peer_service stream_name], unique: true, name: "idx_sync_cursor_peer_stream_uniq"
  end
end
