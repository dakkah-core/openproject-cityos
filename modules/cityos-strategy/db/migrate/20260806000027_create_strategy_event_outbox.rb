# frozen_string_literal: true

# HEXP-0301: Transactional Event Outbox
# Every strategy mutation writes to this table in the same DB transaction.
# A background publisher drains the outbox to NATS JetStream.
class CreateStrategyEventOutbox < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_event_outbox do |t|
      t.string :event_id, null: false
      t.string :event_type, null: false             # e.g., cityos.helm.strategy.baselined.v1
      t.string :aggregate_type, null: false          # e.g., StrategicPlan
      t.string :aggregate_id, null: false            # stable_id
      t.string :event_subject, null: false           # NATS subject
      t.jsonb :payload, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.string :correlation_id
      t.string :causation_id
      t.string :source_revision
      t.string :tenant_id
      t.string :schema_version, null: false, default: "cityos.event.v1"
      t.integer :publish_attempts, null: false, default: 0
      t.datetime :published_at
      t.string :publish_status, null: false, default: "pending"
      # enum: pending, published, failed, dlq, skipped
      t.text :publish_error
      t.timestamps
    end

    add_index :cityos_strategy_event_outbox, :event_id, unique: true
    add_index :cityos_strategy_event_outbox, :publish_status
    add_index :cityos_strategy_event_outbox, [:publish_status, :created_at],
              name: "idx_outbox_publish_fifo"
  end
end
