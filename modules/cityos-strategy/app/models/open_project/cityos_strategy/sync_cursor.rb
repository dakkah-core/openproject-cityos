# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class SyncCursor < ActiveRecord::Base
      self.table_name = "cityos_strategy_sync_cursors"

      PEER_SERVICES = %w[work-control dwos ucl assurance-evidence documentation-fabric].freeze
      CONFLICT_STATES = %w[clean conflict unresolved].freeze
      SYNC_RESULTS = %w[no-op applied conflicted error].freeze

      validates :cursor_id, presence: true, uniqueness: true
      validates :peer_service, presence: true, inclusion: { in: PEER_SERVICES }
      validates :stream_name, presence: true
      validates :conflict_state, inclusion: { in: CONFLICT_STATES }
      validates :last_sync_result, inclusion: { in: SYNC_RESULTS }, allow_nil: true

      before_validation :generate_cursor_id, on: :create

      scope :in_conflict, -> { where(conflict_state: %w[conflict unresolved]) }
      scope :for_peer, ->(service) { where(peer_service: service) }

      def record_sync(result:, cursor_value: nil, before_hash: nil, after_hash: nil, correlation_id: nil)
        update!(
          last_sync_result: result,
          last_cursor_value: cursor_value || last_cursor_value,
          before_hash: before_hash,
          after_hash: after_hash,
          conflict_state: result == 'conflicted' ? 'conflict' : 'clean',
          correlation_id: correlation_id,
          synced_at: Time.current
        )
      end

      private

      def generate_cursor_id
        self.cursor_id ||= "cur-#{SecureRandom.uuid}"
      end
    end
  end
end
