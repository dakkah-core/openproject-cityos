# frozen_string_literal: true

module OpenProject
  module CityOSStrategy
    # Adapter stubs for importing KPI observations and budget actuals
    # from external systems (Data Analytics, Tryton ERP).
    #
    # These are adapter interfaces — actual implementation requires
    # the cityos-strategy-sync service (S6.5) and live system connections.

    class DataAnalyticsAdapter
      # Import KPI observations from external analytics platform
      # Stub: returns empty. Real implementation in cityos-strategy-sync.
      def import_observations(metric_definition, since: 30.days.ago)
        # Future: call Data Analytics REST API, transform, create MetricObservations
        []
      end

      def available?
        false # Stub — not yet connected
      end
    end

    class TrytonBudgetAdapter
      # Import budget actuals from Tryton ERP
      # Stub: returns empty. Real implementation in cityos-strategy-sync.
      def import_budget_actuals(initiative, fiscal_period: nil)
        # Future: call Tryton JSON-RPC, map account.move lines → benefit current_value
        []
      end

      def available?
        false # Stub — not yet connected
      end
    end
  end
end
