# frozen_string_literal: true

module CityOS
  module Strategy
    class VarianceController < ApplicationController
      # Planned vs actual vs forecast views
      def show
        @plan = StrategicPlan.find_by(status: :active)
        @health_service = HealthService.new

        # Objective variance: planned health vs current
        @objective_variance = @plan.objectives.includes(:key_results).map do |o|
          health = @health_service.objective_health(o)
          { id: o.objective_id, title: o.title, status: o.status, health: health }
        end if @plan

        # Initiative cost variance
        @cost_variance = StrategicInitiative.where(stage: :activated).map do |i|
          actual = i.execution_links.includes(:work_package)
                    .sum { |l| l.work_package&.estimated_hours.to_f }
          {
            initiative_id: i.initiative_id, title: i.title,
            estimated_cost: i.estimated_cost,
            actual_hours: actual,
            variance: (i.estimated_cost || 0) - actual
          }
        end

        # Metric forecast (simple linear projection)
        @forecasts = MetricDefinition.includes(:observations).map do |m|
          recent = m.observations.recent.limit(5).pluck(:value)
          target = m.targets.order(period_end: :desc).first
          {
            metric_id: m.metric_id, name: m.name,
            current: recent.first,
            target: target&.target,
            forecast: simple_forecast(recent),
            on_track: target ? on_track?(recent.first, target.target, m.direction) : nil
          }
        end
      end

      private

      def simple_forecast(values)
        return nil if values.size < 2
        # Simple moving average projection
        avg_change = values.each_cons(2).map { |a, b| b - a }.sum / (values.size - 1).to_f
        values.first + (avg_change * 2)
      end

      def on_track?(current, target, direction)
        return false unless current && target
        if direction == "higher_better"
          current >= target
        else
          current <= target
        end
      end
    end
  end
end
