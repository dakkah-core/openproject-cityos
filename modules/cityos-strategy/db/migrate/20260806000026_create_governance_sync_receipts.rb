# frozen_string_literal: true

# HEXP-0204: Governance sync receipts — audit trail for stable-ID sync
class CreateGovernanceSyncReceipts < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_governance_sync_receipts do |t|
      t.references :work_package, foreign_key: true
      t.string :external_id, null: false
      t.string :sync_identity, null: false
      t.string :source_service_id
      t.string :source_revision
      t.string :source_cursor
      t.string :idempotency_key, null: false
      t.string :correlation_id
      t.jsonb :projection_snapshot, default: {}
      t.string :receipt_status, default: "applied"
      t.datetime :projected_at, null: false
      t.timestamps
    end

    add_index :cityos_strategy_governance_sync_receipts, :external_id
    add_index :cityos_strategy_governance_sync_receipts, :idempotency_key, unique: true
    add_index :cityos_strategy_governance_sync_receipts, :sync_identity
  end
end
