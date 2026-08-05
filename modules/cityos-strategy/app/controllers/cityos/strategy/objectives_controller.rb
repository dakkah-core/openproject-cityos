# frozen_string_literal: true

module Cityos
  module Strategy
    class ObjectivesController < ApplicationController
  before_action :find_optional_project
  no_authorization_required! :index, :show

      before_action :find_objective, only: %i[show edit update destroy score]

      def index
        @plan = OpenProject::CityosStrategy::StrategicPlan.find(params[:plan_id]) if params[:plan_id]
        @objectives = if @plan
                        @plan.objectives.includes(:key_results, :theme, :outcome, :owner)
                      else
                        OpenProject::CityosStrategy::StrategicObjective.includes(:plan, :key_results).order(updated_at: :desc)
                      end
      end

      def show
        @key_results = @objective.key_results.order(:created_at)
        @initiatives = @objective.initiatives.includes(:portfolio)
        @child_objectives = @objective.child_objectives
      end

      def new
        @plan = OpenProject::CityosStrategy::StrategicPlan.find(params[:plan_id]) if params[:plan_id]
        @objective = OpenProject::CityosStrategy::StrategicObjective.new(plan: @plan, status: :draft)
      end

      def create
        @objective = OpenProject::CityosStrategy::StrategicObjective.new(objective_params)
        if @objective.save
          redirect_to objective_path(@objective), notice: t(:notice_successful_create)
        else
          render :new
        end
      end

      def edit; end

      def update
        if @objective.update(objective_params)
          redirect_to objective_path(@objective), notice: t(:notice_successful_update)
        else
          render :edit
        end
      end

      def score
        @objective.compute_health!
        redirect_to objective_path(@objective), notice: "Health: #{@objective.health}"
      end

      def destroy
        @objective.update!(status: :closed)
        redirect_to objectives_path, notice: t(:notice_successful_delete)
      end

      private

      def find_objective
        @objective = OpenProject::CityosStrategy::StrategicObjective.find(params[:id])
      end

      def objective_params
        params.require(:strategic_objective).permit(
          :objective_id, :title, :description, :plan_id,
          :theme_id, :outcome_id, :parent_objective_id, :owner_id, :status
        )
      end
    end
  end
end
