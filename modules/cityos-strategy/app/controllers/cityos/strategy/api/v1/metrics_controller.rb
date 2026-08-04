# frozen_string_literal: true

module Cityos
  module Strategy
    module Api
      module V1
        class MetricsController < ApplicationController
          skip_before_action :verify_authenticity_token
          before_action :require_strategy_api_access

          def index
            render json: MetricDefinition.includes(:targets).map { |m|
              latest = m.latest_observation
              {
                metric_id: m.metric_id, name: m.name, direction: m.direction,
                frequency: m.frequency, source_system: m.source_system,
                latest_value: latest&.value, freshness: m.freshness_status
              }
            }
          end

          def show
            m = MetricDefinition.find_by!(metric_id: params[:id])
            render json: {
              metric_id: m.metric_id, name: m.name, description: m.description,
              formula: m.formula, unit: m.unit, direction: m.direction,
              targets: m.targets.map { |t|
                { baseline: t.baseline, target: t.target, floor: t.floor,
                  ceiling: t.ceiling, period: "#{t.period_start}..#{t.period_end}" }
              },
              recent_observations: m.observations.recent.limit(10).map { |o|
                { value: o.value, observed_at: o.observed_at, freshness: o.freshness,
                  confidence: o.confidence, quality: o.quality_state }
              }
            }
          end

          def record_observation
            m = MetricDefinition.find_by!(metric_id: params[:id])
            obs = m.observations.create!(
              value: params[:value], observed_at: params[:observed_at] || Time.current,
              target_id: params[:target_id], source_system: params[:source_system],
              source_metric_id: params[:source_metric_id],
              freshness: params[:freshness] || "current",
              confidence: params[:confidence] || "medium",
              quality_state: params[:quality_state] || "verified",
              evidence_ref: params[:evidence_ref]
            )
            render json: { id: obs.id, value: obs.value, observed_at: obs.observed_at }, status: :created
          end
        end
      end
    end
  end
end
