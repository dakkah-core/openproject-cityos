# frozen_string_literal: true

module Cityos
  module Strategy
    class ScenariosController < ApplicationController
  before_action :find_optional_project

      before_action :find_scenario, only: %i[show edit update destroy freeze unfreeze compare]

      def index
        @scenarios = PlanningScenario.order(planning_cycle: :desc, created_at: :desc)
      end

      def show
        @initiatives = @scenario.initiatives.includes(:portfolio, :owner)
        @allocations = @scenario.allocations.group_by(&:dimension)
        @issues = ScenarioService.new.validate_constraints(@scenario)
      end

      def new
        @scenario = PlanningScenario.new(status: :draft, version: 1)
      end

      def create
        @scenario = PlanningScenario.new(scenario_params)
        if @scenario.save
          redirect_to scenario_path(@scenario), notice: t(:notice_successful_create)
        else
          render :new
        end
      end

      def edit; end

      def update
        if @scenario.update(scenario_params)
          redirect_to scenario_path(@scenario), notice: t(:notice_successful_update)
        else
          render :edit
        end
      end

      def freeze
        ScenarioService.new.freeze(@scenario)
        redirect_to scenario_path(@scenario), notice: "Scenario frozen (v#{@scenario.version})"
      end

      def unfreeze
        @scenario.unfreeze!
        redirect_to scenario_path(@scenario), notice: "Scenario unfrozen"
      end

      def compare
        @other = PlanningScenario.find(params[:other_id])
        @comparison = ScenarioService.new.compare(@scenario, @other)
      end

      def destroy
        @scenario.update!(status: :rejected)
        redirect_to scenarios_path, notice: t(:notice_successful_delete)
      end

      private

      def find_scenario
        @scenario = PlanningScenario.find(params[:id])
      end

      def scenario_params
        params.require(:planning_scenario).permit(
          :scenario_id, :planning_cycle, :name, :assumptions,
          :status, :funding_allocation, :capacity_allocation,
          :constraint_violations, :recommendation_status
        )
      end
    end
  end
end
