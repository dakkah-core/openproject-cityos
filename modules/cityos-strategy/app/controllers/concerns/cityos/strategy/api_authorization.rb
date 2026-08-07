# frozen_string_literal: true

# Wave 1 W1-4 (2026-08-07): shared authorization concern for the strategy
# API v1 controllers. Replaces the 6 inline `def require_strategy_api_access;
# true; end` stubs that literally returned true and delegated auth "to the
# gateway" — verified as P0.2 (CONFIRMED) by the 14-agent adversarial workflow.
#
# Trust model:
#   * Every request must present a strategy API token via one of:
#       X-CityOS-Strategy-Token: <raw>
#       Authorization: Bearer <raw>
#   * The raw token is SHA-256 hashed and looked up against
#     cityos_strategy_machine_identities.
#   * The identity must be active AND (if declared) hold the scope required
#     for the current controller.
#   * `last_used_at` is stamped on success (best-effort, no DB rollback if it
#     fails).
#   * `@current_machine_identity` is exposed to the controller for logging.
#
# Usage:
#   module Cityos::Strategy::API::V1
#     class CoverageController < ApplicationController
#       skip_before_action :verify_authenticity_token
#       include Cityos::Strategy::ApiAuthorization
#       requires_api_scope "strategy.coverage"
#       # ... actions ...
#     end
#   end
module Cityos
  module Strategy
    module ApiAuthorization
      extend ActiveSupport::Concern

      TOKEN_HEADER = "HTTP_X_CITYOS_STRATEGY_TOKEN"
      AUTHZ_HEADER = "HTTP_AUTHORIZATION"

      included do
        before_action :require_strategy_api_access
        attr_reader :current_machine_identity
      end

      class_methods do
        # Declare the scope this controller (or overriding action) requires
        # on the presenting token. If nil, no scope check is applied — the
        # token just needs to be valid + active.
        def requires_api_scope(scope)
          @required_api_scope = scope.to_s
        end

        def required_api_scope
          @required_api_scope
        end
      end

      private

      def require_strategy_api_access
        raw = extract_strategy_api_token
        if raw.blank?
          return render json: {
            error: "unauthorized",
            detail: "missing strategy API token (need X-CityOS-Strategy-Token or Authorization: Bearer)"
          }, status: :unauthorized
        end

        identity = OpenProject::CityosStrategy::MachineIdentity.authenticate_token(raw)
        unless identity
          return render json: {
            error: "unauthorized",
            detail: "strategy API token is invalid, expired, or revoked"
          }, status: :unauthorized
        end

        scope = self.class.required_api_scope
        if scope.present? && !identity.has_scope?(scope)
          return render json: {
            error: "forbidden",
            detail: "token lacks required scope: #{scope}",
            required_scope: scope,
            token_name: identity.name
          }, status: :forbidden
        end

        @current_machine_identity = identity

        # Best-effort last-used stamp; do not fail the request if the write
        # fails (identity is authenticated; the stamp is operability metadata).
        begin
          identity.update_column(:last_used_at, Time.current)
        rescue StandardError => e
          Rails.logger.warn("[strategy-api-auth] failed to stamp last_used_at for identity #{identity.stable_id}: #{e.message}")
        end

        true
      end

      def extract_strategy_api_token
        direct = request.env[TOKEN_HEADER]
        return direct.to_s.strip if direct.present?

        authz = request.env[AUTHZ_HEADER].to_s
        return authz.sub(/\ABearer\s+/, "").strip if authz.start_with?("Bearer ")

        nil
      end
    end
  end
end
