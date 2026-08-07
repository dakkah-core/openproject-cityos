# frozen_string_literal: true

module Cityos
  module Strategy
    module API
      module V1
        class ObjectivesController < ApplicationController
          skip_before_action :verify_authenticity_token
          include Cityos::Strategy::ApiAuthorization
          requires_api_scope "strategy.read"

          def index
            render json: OpenProject::CityosStrategy::StrategicObjective.includes(:key_results).map { |o|
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
            o = OpenProject::CityosStrategy::StrategicObjective.find_by!(objective_id: params[:id])
            render json: {
              objective_id: o.objective_id, title: o.title, description: o.description,
              status: o.status, health: o.health, plan: o.plan&.title,
              key_results: o.key_results.map { |kr|
                { title: kr.title, baseline: kr.baseline_value, target: kr.target_value,
                  current: kr.current_value, unit: kr.unit, status: kr.status }
              }
            }
          end

        end
      end
    end
  end
end
