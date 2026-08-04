# frozen_string_literal: true

module CityOS
  module Strategy
    class ScorecardController < ApplicationController
      # KPI scorecard — all metrics with targets, actuals, trends, freshness
      def show
        @metrics = MetricDefinition.includes(:targets).order(:name)
        @health_service = HealthService.new

        @scorecard = @metrics.map do |m|
          target = m.targets.order(period_end: :desc).first
          latest = m.latest_observation
          health = @health_service.metric_health(m)

          {
            metric_id: m.metric_id,
            name: m.name,
            direction: m.direction,
            target: target&.target,
            floor: target&.floor,
            ceiling: target&.ceiling,
            latest_value: latest&.value,
            freshness: m.freshness_status,
            health: health,
            trend: compute_trend(m)
          }
        end

        # Summary stats
        @healthy = @scorecard.count { |s| s[:health] == :on_target }
        @at_risk = @scorecard.count { |s| %i[below_target above_target].include?(s[:health]) }
        @critical = @scorecard.count { |s| %i[below_threshold above_threshold].include?(s[:health]) }
        @no_data = @scorecard.count { |s| %i[no_target no_data].include?(s[:health]) }
      end

      private

      def compute_trend(metric)
        recent = metric.observations.recent.limit(3).pluck(:value)
        return :stable if recent.size < 2

        if recent.first > recent.last
          metric.direction == "higher_better" ? :improving : :declining
        elsif recent.first < recent.last
          metric.direction == "higher_better" ? :declining : :improving
        else
          :stable
        end
      end
    end
  end
end
