# frozen_string_literal: true

module Cityos
  module Strategy
    class AllocationsController < ApplicationController
  before_action :find_optional_project

      before_action :find_scenario, only: %i[index create]

      # Allocation dashboard for a scenario
      def index
        @allocations = @scenario.allocations.includes(:initiative).group_by(&:dimension)

        # Compute totals by dimension
        @totals = StrategicAllocation::DIMENSIONS.keys.index_with do |dim|
          (@allocations[dim.to_s] || []).sum { |a| a.amount || 0 }
        end

        # Funding distribution across initiatives
        @funding_distribution = @scenario.allocations
                                         .where(dimension: :funding)
                                         .includes(:initiative)
                                         .order(amount: :desc)
      end

      # Create or update an allocation
      def create
        allocation = @scenario.allocations.find_or_initialize_by(
          initiative_id: params[:initiative_id],
          dimension: params[:dimension]
        )
        allocation.update!(
          amount: params[:amount],
          unit: params[:unit] || "SAR"
        )
        redirect_to scenario_allocations_path(@scenario),
                    notice: "Allocation updated: #{allocation.dimension} = #{allocation.amount} #{allocation.unit}"
      end

      private

      def find_scenario
        @scenario = PlanningScenario.find(params[:scenario_id])
      end
    end
  end
end
