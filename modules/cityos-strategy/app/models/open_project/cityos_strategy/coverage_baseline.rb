# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class CoverageBaseline < ActiveRecord::Base
      self.table_name = "cityos_strategy_coverage_baselines"

      belongs_to :owner, class_name: "User", optional: true

      validates :baseline_id, presence: true, uniqueness: true
      validates :universe_version, presence: true
      validates :node_set_hash, presence: true

      scope :active, -> { where(superseded_by: nil).where("effective_until IS NULL OR effective_until > ?", Date.current) }

      def superseded?
        superseded_by.present?
      end

      def node_count
        included_node_set&.size || 0
      end
    end
  end
end
