# frozen_string_literal: true

module CityOS
  module Strategy
    class PlansController < ApplicationController
      before_action :find_plan, only: %i[show edit update destroy baseline]

      def index
        @plans = StrategicPlan.order(effective_from: :desc)
      end

      def show
        @objectives = @plan.objectives.includes(:key_results, :theme, :outcome)
      end

      def new
        @plan = StrategicPlan.new(status: :draft, version: 1)
      end

      def create
        @plan = StrategicPlan.new(plan_params)
        if @plan.save
          redirect_to plans_path, notice: t(:notice_successful_create)
        else
          render :new
        end
      end

      def edit; end

      def update
        if @plan.update(plan_params)
          redirect_to plan_path(@plan), notice: t(:notice_successful_update)
        else
          render :edit
        end
      end

      def baseline
        @plan.baseline!
        redirect_to plan_path(@plan), notice: "Plan baselined as version #{@plan.version}"
      end

      def destroy
        @plan.update!(status: :archived)
        redirect_to plans_path, notice: t(:notice_successful_delete)
      end

      private

      def find_plan
        @plan = StrategicPlan.find(params[:id])
      end

      def plan_params
        params.require(:strategic_plan).permit(
          :title, :description, :plan_type, :status,
          :effective_from, :effective_to, :owner_id,
          :parent_plan_id, :document_ref
        )
      end
    end
  end
end
