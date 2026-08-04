# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class HealthService
      # Compute objective health from key result statuses
      def objective_health(objective)
        krs = objective.key_results
        return :unknown if krs.empty?

        statuses = krs.map(&:status)
        if statuses.all? { |s| s == "on_track" }
          :on_track
        elsif statuses.any? { |s| %w[at_risk behind].include?(s) }
          :off_track
        else
          :at_risk
        end
      end

      # Compute metric health from latest observation vs target threshold
      def metric_health(metric)
        target = metric.targets.order(period_end: :desc).first
        return :no_target unless target

        obs = metric.latest_observation
        return :no_data unless obs

        floor = target.floor
        ceiling = target.ceiling

        if floor && ceiling
          if obs.value < floor
            :below_threshold
          elsif obs.value > ceiling
            :above_threshold
          else
            :on_target
          end
        elsif metric.direction == "higher_better"
          obs.value >= target.target ? :on_target : :below_target
        else
          obs.value <= target.target ? :on_target : :above_target
        end
      end

      # Overall plan health — aggregate of all objective healths
      def plan_health(plan)
        objectives = plan.objectives
        return :no_objectives if objectives.empty?

        healths = objectives.map { |o| objective_health(o) }
        off_track = healths.count { |h| h == :off_track }
        at_risk = healths.count { |h| h == :at_risk }

        if off_track > (objectives.size * 0.3)
          :critical
        elsif (off_track + at_risk) > (objectives.size * 0.3)
          :needs_attention
        else
          :healthy
        end
      end

      # Compute benefit realization status
      def benefit_status(benefit)
        return :not_started unless benefit.current_value

        baseline = benefit.baseline || 0
        target = benefit.target
        current = benefit.current_value

        range = target - baseline
        return :realized if range.zero?
        percent = ((current - baseline) / range * 100).round(1)

        if percent >= 100
          :realized
        elsif percent >= 75
          :on_track
        elsif percent >= 25
          :at_risk
        else
          :behind
        end
      end
    end
  end
end
