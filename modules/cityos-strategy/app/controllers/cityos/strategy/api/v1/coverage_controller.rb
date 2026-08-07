# frozen_string_literal: true

module Cityos
  module Strategy
    module API
      module V1
        class CoverageController < ApplicationController
          skip_before_action :verify_authenticity_token
          include Cityos::Strategy::ApiAuthorization
          requires_api_scope "strategy.coverage"

          # GET /api/cityos/v1/coverage/baselines
          def baselines
            baselines = OpenProject::CityosStrategy::CoverageBaseline.all.order(created_at: :desc)
            render json: { baselines: baselines.map { |b| serialize_baseline(b) }, count: baselines.count }
          end

          # POST /api/cityos/v1/coverage/baselines
          def create_baseline
            baseline = OpenProject::CityosStrategy::CoverageService.create_baseline(
              universe_version: params[:universe_version],
              node_set: params[:node_set] || [],
              owner: User.current
            )
            render json: { baseline: serialize_baseline(baseline) }, status: :created
          rescue ActiveRecord::RecordInvalid => e
            render json: { error: e.message }, status: :unprocessable_entity
          end

          # GET /api/cityos/v1/coverage/baselines/:id/compare?other=:other_id
          def compare_baselines
            result = OpenProject::CityosStrategy::CoverageService.compare_baselines(
              params[:id], params[:other]
            )
            render json: result
          end

          # GET /api/cityos/v1/coverage/baselines/:id/gaps
          def gaps
            result = OpenProject::CityosStrategy::CoverageService.detect_gaps(params[:id])
            render json: result
          end

          # GET /api/cityos/v1/coverage/targets
          def targets
            targets = OpenProject::CityosStrategy::CoverageTarget.where(baseline_id: params[:baseline_id])
            render json: { targets: targets.map { |t| serialize_target(t) }, count: targets.count }
          end

          # POST /api/cityos/v1/coverage/targets
          def create_target
            target = OpenProject::CityosStrategy::CoverageTarget.create!(target_params)
            render json: { target: serialize_target(target) }, status: :created
          end

          private

          def target_params
            params.permit(:objective_id, :universe_node, :coverage_dimension,
                          :baseline_id, :target_pct, :target_date, :source_metric, :measurement_policy)
          end

          def serialize_baseline(b)
            { baseline_id: b.baseline_id, version: b.version, universe_version: b.universe_version,
              node_count: b.node_count, node_set_hash: b.node_set_hash, approval_ref: b.approval_ref,
              effective_from: b.effective_from, superseded_by: b.superseded_by, created_at: b.created_at }
          end

          def serialize_target(t)
            { target_id: t.target_id, universe_node: t.universe_node, coverage_dimension: t.coverage_dimension,
              baseline_id: t.baseline_id, target_pct: t.target_pct.to_f, current_pct: t.current_pct.to_f,
              achieved: t.achieved?, gap: t.gap, measurement_policy: t.measurement_policy }
          end

        end
      end
    end
  end
end
