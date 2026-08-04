# frozen_string_literal: true

module CityOS
  module Strategy
    module Api
      module V1
        class ObjectivesController < ApplicationController
          skip_before_action :verify_authenticity_token
          before_action :require_strategy_api_access

          def index
            render json: StrategicObjective.includes(:key_results).map { |o|
              {
                objective_id: o.objective_id, title: o.title,
                status: o.status, health: o.health,
                key_results: o.key_results.map { |kr|
                  { title: kr.title, target: kr.target_value, current: kr.current_value, unit: kr.unit }
                }
              }
            }
          end

          def show
            o = StrategicObjective.find_by!(objective_id: params[:id])
            render json: {
              objective_id: o.objective_id, title: o.title, description: o.description,
              status: o.status, health: o.health, plan: o.plan&.title,
              key_results: o.key_results.map { |kr|
                { title: kr.title, baseline: kr.baseline_value, target: kr.target_value,
                  current: kr.current_value, unit: kr.unit, status: kr.status }
              }
            }
          end

          private

          def require_strategy_api_access
            # Verified via MCP token or sync service token
            head :forbidden unless User.current&.allowed_to?(:access_strategy_api, @project)
          end
        end
      end
    end
  end
end
