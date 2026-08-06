# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class ObligationCoverageService
      ALL_SERVICE_IDS = EngineeringServiceBindings::SERVICE_IDS.freeze

      # Returns percentage of required services with fulfilled obligations for an objective
      def self.compute_coverage(objective_id: nil, initiative_id: nil)
        bindings = scope(objective_id:, initiative_id:).required
        return 0.0 if bindings.empty? && ALL_SERVICE_IDS.empty?

        fulfilled = bindings.fulfilled.count
        total = ALL_SERVICE_IDS.size
        ((fulfilled.to_f / total) * 100).round(1)
      end

      # Returns services with no binding or pending/blocked status
      def self.missing_obligations(objective_id: nil, initiative_id: nil)
        bound_service_ids = scope(objective_id:, initiative_id:)
                              .pluck(:service_id)
                              .uniq

        unbound = ALL_SERVICE_IDS - bound_service_ids
        pending_or_blocked = scope(objective_id:, initiative_id:)
                               .pending_or_blocked
                               .pluck(:service_id)

        {
          unbound:,
          pending_or_blocked:,
          total_missing: unbound.size + pending_or_blocked.size,
          coverage_pct: compute_coverage(objective_id:, initiative_id:)
        }
      end

      # Returns initiatives where a required service obligation is blocked
      def self.blocked_initiatives
        StrategicInitiative
          .joins("INNER JOIN cityos_strategy_engineering_service_bindings esb ON esb.initiative_id = cityos_strategy_initiatives.id")
          .where(esb: { status: 'blocked', role: 'required' })
          .distinct
      end

      # Creates default bindings for all 17 services on an objective
      def self.create_defaults!(objective_id: nil, initiative_id: nil)
        ALL_SERVICE_IDS.map do |service_id|
          EngineeringServiceBindings.create!(
            objective_id:,
            initiative_id:,
            service_id:,
            role: 'required',
            status: 'pending'
          )
        end
      end

      private

      def self.scope(objective_id:, initiative_id:)
        bindings = EngineeringServiceBindings.all
        bindings = bindings.for_objective(objective_id) if objective_id
        bindings = bindings.for_initiative(initiative_id) if initiative_id
        bindings
      end
    end
  end
end
