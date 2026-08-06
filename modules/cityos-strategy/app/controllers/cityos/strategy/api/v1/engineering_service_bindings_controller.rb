# frozen_string_literal: true

module Cityos
  module Strategy
    module API
      module V1
        class EngineeringServiceBindingsController < ApplicationController
          skip_before_action :verify_authenticity_token
          before_action :require_strategy_api_access

          # GET /api/cityos/v1/engineering_service_bindings?objective_id=X
          def index
            bindings = scope
            render json: {
              bindings: bindings.map { |b| serialize_binding(b) },
              count: bindings.count,
              coverage: OpenProject::CityosStrategy::ObligationCoverageService.compute_coverage(
                objective_id: params[:objective_id].presence,
                initiative_id: params[:initiative_id].presence
              )
            }
          end

          # GET /api/cityos/v1/engineering_service_bindings/:id
          def show
            binding = OpenProject::CityosStrategy::EngineeringServiceBindings.find_by!(binding_id: params[:id])
            render json: { binding: serialize_binding(binding) }
          end

          # POST /api/cityos/v1/engineering_service_bindings
          def create
            binding = OpenProject::CityosStrategy::EngineeringServiceBindings.create!(binding_params)
            render json: { binding: serialize_binding(binding) }, status: :created
          rescue ActiveRecord::RecordInvalid => e
            render json: { error: e.message }, status: :unprocessable_entity
          end

          # PATCH /api/cityos/v1/engineering_service_bindings/:id
          def update
            binding = OpenProject::CityosStrategy::EngineeringServiceBindings.find_by!(binding_id: params[:id])
            binding.update!(update_params)
            render json: { binding: serialize_binding(binding) }
          end

          # POST /api/cityos/v1/engineering_service_bindings/create_defaults
          def create_defaults
            results = OpenProject::CityosStrategy::ObligationCoverageService.create_defaults!(
              objective_id: params[:objective_id].presence,
              initiative_id: params[:initiative_id].presence
            )
            render json: { created: results.size, bindings: results.map { |b| serialize_binding(b) } }, status: :created
          rescue ActiveRecord::RecordInvalid => e
            render json: { error: e.message }, status: :unprocessable_entity
          end

          # GET /api/cityos/v1/engineering_service_bindings/coverage
          def coverage
            missing = OpenProject::CityosStrategy::ObligationCoverageService.missing_obligations(
              objective_id: params[:objective_id].presence,
              initiative_id: params[:initiative_id].presence
            )
            render json: missing
          end

          private

          def scope
            bindings = OpenProject::CityosStrategy::EngineeringServiceBindings.all
            bindings = bindings.where(objective_id: params[:objective_id]) if params[:objective_id].present?
            bindings = bindings.where(initiative_id: params[:initiative_id]) if params[:initiative_id].present?
            bindings = bindings.where(service_id: params[:service_id]) if params[:service_id].present?
            bindings
          end

          def binding_params
            params.permit(:objective_id, :initiative_id, :service_id, :role,
                          :status, input_obligations: {}, output_obligations: {},
                          entry_conditions: {}, exit_conditions: {})
          end

          def update_params
            params.permit(:status, :role, input_obligations: {}, output_obligations: {},
                          entry_conditions: {}, exit_conditions: {})
          end

          def serialize_binding(b)
            {
              binding_id: b.binding_id,
              objective_id: b.objective_id,
              initiative_id: b.initiative_id,
              service_id: b.service_id,
              role: b.role,
              status: b.status,
              input_obligations: b.input_obligations,
              output_obligations: b.output_obligations,
              entry_conditions: b.entry_conditions,
              exit_conditions: b.exit_conditions,
              target_sla: b.target_sla,
              created_at: b.created_at,
              updated_at: b.updated_at
            }
          end

          def require_strategy_api_access
            true  # API token auth — permission checked at gateway level
          end
        end
      end
    end
  end
end
