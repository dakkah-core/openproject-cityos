# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class ReleaseScopeBinding < ActiveRecord::Base
      self.table_name = "cityos_strategy_release_scope_bindings"

      SCOPE_TYPES = %w[capability initiative work_package artifact].freeze
      POSTURES = %w[compatible breaking deprecated].freeze

      validates :binding_id, presence: true, uniqueness: true
      validates :scope_type, presence: true, inclusion: { in: SCOPE_TYPES }
      validates :scope_id, presence: true
      validates :compatibility_posture, inclusion: { in: POSTURES }

      before_validation :generate_binding_id, on: :create

      private

      def generate_binding_id
        self.binding_id ||= "rsb-#{SecureRandom.uuid}"
      end
    end
  end
end
