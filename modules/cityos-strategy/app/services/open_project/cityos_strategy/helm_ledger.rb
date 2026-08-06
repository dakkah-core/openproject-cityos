# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class HelmLedger
      BRIDGE_URL = ENV.fetch('HELM_BRIDGE_URL', 'http://localhost:3062')

      def self.publish_plan_authorized(plan_id:, authorization_id:, strategy_ref:, work_items:)
        payload = {
          planId: "op-wp-#{plan_id}",
          strategyRef: strategy_ref,
          workItems: work_items,
          authorizationId: authorization_id
        }

        response = Faraday.post("#{BRIDGE_URL}/api/helm/publish", payload.to_json, {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        })

        { success: response.success?, status: response.status, body: JSON.parse(response.body) }
      rescue Faraday::Error => e
        Rails.logger.error("[HelmLedger] Bridge publish failed: #{e.message}")
        { success: false, error: e.message }
      end
    end
  end
end
