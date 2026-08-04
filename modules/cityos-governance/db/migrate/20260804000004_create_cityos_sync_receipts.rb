class CreateCityosSyncReceipts < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_sync_receipts do |t|
      t.string :receipt_id, null: false, index: { unique: true }
      t.string :source_revision
      t.string :operation, null: false
      t.string :target_type
      t.integer :target_id
      t.string :before_hash
      t.string :after_hash
      t.string :correlation_id
      t.string :actor_id
      t.string :result, null: false
      t.text :error_detail

      t.timestamp :created_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    end

    add_index :cityos_sync_receipts, :correlation_id
    add_index :cityos_sync_receipts, :created_at
    add_index :cityos_sync_receipts, :result
  end
end
