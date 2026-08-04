# frozen_string_literal: true

module Cityos
  module Strategy
    class PlansController < ApplicationController
      before_action :find_plan, only: %i[show edit update destroy baseline replan]

      def index
        @plans = StrategicPlan.order(effective_from: :desc)
      end

      def show
        @objectives = @plan.objectives.includes(:key_results, :theme, :outcome)
        @previous_versions = StrategicPlan.where(parent_plan_id: @plan.id).order(version: :desc)
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

      # S5.8: Replan and supersession workflow
      def replan
        # Archive current plan
        @plan.update!(status: :superseded)

        # Create new plan version with lineage
        new_plan = StrategicPlan.create!(
          title: "#{@plan.title} (v#{@plan.version + 1})",
          description: @plan.description,
          plan_type: @plan.plan_type,
          status: :draft,
          effective_from: @plan.effective_to&.next_day || Date.tomorrow,
          version: 1,
          owner_id: @plan.owner_id,
          parent_plan_id: @plan.id,
          scoring_config: @plan.scoring_config
        )

        redirect_to plan_path(new_plan), notice: "New plan version created from #{@plan.title}"
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
