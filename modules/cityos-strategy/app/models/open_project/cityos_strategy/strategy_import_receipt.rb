# frozen_string_literal: true

# Wave 4 W4-1 (2026-08-07): audit record for a governed strategy import run.
#
# One row per invocation of Cityos::Strategy::Importer regardless of mode
# (dry-run / apply-draft / verify / export). Records are audit evidence:
# writable at creation, then read-only. Deletion goes through the standard
# retention policy — never manual.
module OpenProject
  module CityosStrategy
    class StrategyImportReceipt < ActiveRecord::Base
      self.table_name = 'cityos_strategy_import_receipts'

      MODES = %w[dry-run apply-draft verify export].freeze
      STATUSES = %w[started completed failed].freeze

      validates :import_id, presence: true, uniqueness: true
      validates :source_path, :source_hash, :mode, :status, presence: true
      validates :mode, inclusion: { in: MODES }
      validates :status, inclusion: { in: STATUSES }

      before_validation :generate_import_id, on: :create

      scope :dry_runs, -> { where(dry_run: true) }
      scope :applied,  -> { where(dry_run: false).where.not(applied_at: nil) }
      scope :failed,   -> { where(status: "failed") }

      private

      def generate_import_id
        self.import_id ||= "import-#{SecureRandom.uuid}"
      end
    end
  end
end
