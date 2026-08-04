# frozen_string_literal: true

module OpenProject
  module CityOSStrategy
    class ScenarioService
      # Freeze a scenario — immutable after freeze
      def freeze(scenario)
        raise "Scenario must be in draft status to freeze" unless scenario.draft?

        scenario.freeze!
        scenario
      end

      # Compare two scenarios side by side
      def compare(scenario_a, scenario_b)
        {
          a: scenario_summary(scenario_a),
          b: scenario_summary(scenario_b),
          diffs: compute_diffs(scenario_a, scenario_b)
        }
      end

      # Validate scenario constraints
      def validate_constraints(scenario)
        issues = []

        # Funding constraint: sum of allocations <= scenario funding
        total_allocated = scenario.allocations
                                  .where(dimension: :funding)
                                  .sum(:amount)
        if total_allocated > (scenario.funding_allocation || 0)
          issues << "Funding overallocated: #{total_allocated} > #{scenario.funding_allocation}"
        end

        # Capacity constraint: count of initiatives with capacity demands
        initiatives = scenario.initiatives
        capacity_count = initiatives.count { |i| i.capacity_demand.present? }
        if capacity_count > 0 && scenario.capacity_allocation.blank?
          issues << "#{capacity_count} initiatives have capacity demands but no capacity allocation"
        end

        # Dependency constraint: blocked initiatives in scenario
        blocked_deps = StrategicDependency.where(
          from_initiative_id: initiatives.pluck(:id),
          status: :broken
        ).count
        issues << "#{blocked_deps} broken dependencies in scenario" if blocked_deps > 0

        issues
      end

      # Generate scenario summary
      def scenario_summary(scenario)
        initiatives = scenario.initiatives.includes(:portfolio)
        {
          scenario_id: scenario.scenario_id,
          name: scenario.name,
          status: scenario.status,
          initiative_count: initiatives.count,
          mandatory_count: initiatives.count { |i| i.bypass_scoring? },
          total_estimated_cost: initiatives.sum(&:estimated_cost),
          funding_allocation: scenario.funding_allocation,
          capacity_allocation: scenario.capacity_allocation,
          initiatives: initiatives.map { |i|
            { id: i.initiative_id, title: i.title, stage: i.stage, cost: i.estimated_cost }
          }
        }
      end

      private

      def compute_diffs(a, b)
        {
          initiative_count: scenario_summary(a)[:initiative_count] - scenario_summary(b)[:initiative_count],
          total_cost: (scenario_summary(a)[:total_estimated_cost] || 0) - (scenario_summary(b)[:total_estimated_cost] || 0),
          only_in_a: initiative_diff(a, b, :only_a),
          only_in_b: initiative_diff(a, b, :only_b)
        }
      end

      def initiative_diff(a, b, direction)
        a_ids = a.initiatives.pluck(:initiative_id)
        b_ids = b.initiatives.pluck(:initiative_id)

        if direction == :only_a
          a.initiatives.where(initiative_id: a_ids - b_ids).pluck(:initiative_id, :title)
        else
          b.initiatives.where(initiative_id: b_ids - a_ids).pluck(:initiative_id, :title)
        end
      end
    end
  end
end
