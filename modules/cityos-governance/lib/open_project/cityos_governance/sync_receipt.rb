module OpenProject
  module CityosGovernance
    # SyncReceipt — append-only record of every governance sync operation.
    # Records before/after hashes, correlation IDs, and actor identity.
    # Used for audit, reconciliation, and drift detection.
    class SyncReceipt < ::ActiveRecord::Base
      self.table_name = 'cityos_sync_receipts'

      validates :receipt_id, presence: true, uniqueness: true
      validates :operation, inclusion: { in: %w[create update noop delete] }
      validates :result, inclusion: { in: %w[success conflict error] }

      scope :by_correlation, ->(correlation_id) { where(correlation_id: correlation_id) }
      scope :by_actor, ->(actor_id) { where(actor_id: actor_id) }
      scope :recent, -> { order(created_at: :desc).limit(100) }
      scope :errors, -> { where(result: 'error') }

      before_validation :set_receipt_id, on: :create

      private

      def set_receipt_id
        self.receipt_id ||= SecureRandom.uuid
      end
    end
  end
end
