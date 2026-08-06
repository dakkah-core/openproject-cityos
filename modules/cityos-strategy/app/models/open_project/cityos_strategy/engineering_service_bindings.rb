# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class EngineeringServiceBindings < ActiveRecord::Base
      self.table_name = "cityos_strategy_engineering_service_bindings"

      SERVICE_IDS = %w[
        helm psee pedd documentation-fabric semantic-universe
        extension-fabric work-control dwos ucl assurance-evidence
        operations-runbook engineering-compiler engineering-connectors
        universal-tool-platform maestro engineering-ai-gateway data-analytics-kpi
      ].freeze

      ROLES = %w[required supporting observer].freeze
      STATUSES = %w[pending in-progress fulfilled blocked].freeze

      belongs_to :objective, class_name: "StrategicObjective", optional: true
      belongs_to :initiative, class_name: "StrategicInitiative", optional: true

      validates :binding_id, presence: true, uniqueness: true
      validates :service_id, presence: true, inclusion: { in: SERVICE_IDS }
      validates :role, inclusion: { in: ROLES }
      validates :status, inclusion: { in: STATUSES }
      validate :objective_or_initiative_present

      before_validation :generate_binding_id, on: :create

      scope :required, -> { where(role: 'required') }
      scope :fulfilled, -> { where(status: 'fulfilled') }
      scope :pending_or_blocked, -> { where(status: %w[pending blocked]) }
      scope :for_objective, ->(id) { where(objective_id: id) }
      scope :for_initiative, ->(id) { where(initiative_id: id) }

      def fulfilled?
        status == 'fulfilled'
      end

      def blocked?
        status == 'blocked'
      end

      private

      def generate_binding_id
        self.binding_id ||= "esb-#{SecureRandom.uuid}"
      end

      def objective_or_initiative_present
        if objective_id.blank? && initiative_id.blank?
          errors.add(:base, "Either objective_id or initiative_id must be present")
        end
      end
    end
  end
end
