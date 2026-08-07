# frozen_string_literal: true

# Wave 4 W4-1 (2026-08-07): StrategyImportReceipt record.
#
# Records every governed import run against the strategy pack (via
# Cityos::Strategy::Importer). Stores the source content hash, the
# import mode (dry-run / apply-draft / verify / export), a JSONB
# per-record delta, and the actor / requested_at metadata. Read-only
# after write — receipts are audit evidence, not editable state.
class CreateStrategyImportReceipts < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_import_receipts do |t|
      t.string  :import_id,     null: false, index: { unique: true }
      t.string  :source_path,   null: false
      t.string  :source_hash,   null: false                 # sha256 of the loaded YAML/JSON
      t.string  :mode,          null: false                 # dry-run | apply-draft | verify | export
      t.string  :status,        null: false, default: "started"
                                              # started | completed | failed
      t.jsonb   :record_deltas, null: false, default: {}    # per-model create/update/no-op counts + refs
      t.jsonb   :verdicts,      null: false, default: []    # per-record HOLDS/CONFLICT/etc
      t.text    :error_message                              # populated when status = failed
      t.integer :actor_id                                   # OpenProject User#id (nullable = system/CLI)
      t.string  :actor_scope    # ApiAuthorization scope, when import came via HTTP
      t.string  :correlation_id # per-run UUID used for logging + outbox correlation
      t.boolean :dry_run,       null: false, default: true
      t.datetime :applied_at    # nil when dry_run or when apply-draft hasn't landed yet
      t.timestamps
    end

    add_index :cityos_strategy_import_receipts, :source_hash
    add_index :cityos_strategy_import_receipts, %i[mode status]
    add_index :cityos_strategy_import_receipts, :actor_id
  end
end
