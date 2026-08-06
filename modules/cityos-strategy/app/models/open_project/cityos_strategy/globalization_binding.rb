# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class GlobalizationBinding < ActiveRecord::Base
      self.table_name = "cityos_strategy_globalization_bindings"

      LANGUAGES = %w[ar en].freeze
      CURRENCIES = %w[SAR USD EUR].freeze

      belongs_to :objective, class_name: "StrategicObjective", optional: true
      belongs_to :initiative, class_name: "StrategicInitiative", optional: true

      validates :binding_id, presence: true, uniqueness: true
      validates :country_cell, presence: true
      validates :language, inclusion: { in: LANGUAGES }
      validates :currency, inclusion: { in: CURRENCIES }
      validate :objective_or_initiative_present

      before_validation :generate_binding_id, on: :create

      scope :for_country, ->(cell) { where(country_cell: cell) }

      private

      def generate_binding_id
        self.binding_id ||= "glob-#{SecureRandom.uuid}"
      end

      def objective_or_initiative_present
        if objective_id.blank? && initiative_id.blank?
          errors.add(:base, "Either objective_id or initiative_id must be present")
        end
      end
    end
  end
end
