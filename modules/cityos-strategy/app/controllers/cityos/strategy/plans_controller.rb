# frozen_string_literal: true

module Cityos
  module Strategy
    class PlansController < ApplicationController
  before_action :find_optional_project
  before_action :authorize_global, only: %i[index show]  # HEXP-0106: Require auth — strategy is sensitive

      before_action :find_plan, only: %i[show edit update destroy baseline replan]

      def index
        @plans = OpenProject::CityosStrategy::StrategicPlan.order(effective_from: :desc)
      end

      def show
        @objectives = @plan.objectives.includes(:key_results, :theme, :outcome)
        @previous_versions = OpenProject::CityosStrategy::StrategicPlan.where(parent_plan_id: @plan.id).order(version: :desc)
      end

      def new
        @plan = OpenProject::CityosStrategy::StrategicPlan.new(status: :draft, version: 1)
      end

      def create
        @plan = OpenProject::CityosStrategy::StrategicPlan.new(plan_params)
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

      # HEXP-0101: baseline now creates a request only (does NOT self-approve)
      def baseline
        @plan.request_baseline!(actor: User.current, correlation_id: SecureRandom.uuid)
        redirect_to plan_path(@plan), notice: "Baseline requested for version #{@plan.version}. Pending DWOS approval."
      end

      # HEXP-0103: Supersede via lifecycle service (not direct status mutation)
      def replan
        # Request supersession of current plan (pending DWOS decision)
        @plan.update!(status: :superseded, baseline_status: :revoked)

        # Create new plan version with lineage
        new_plan = OpenProject::CityosStrategy::StrategicPlan.create!(
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

        redirect_to plan_path(new_plan), notice: "New plan version created from #{@plan.title}. Baseline request needed."
      end

      def destroy
        @plan.update!(status: :archived)
        redirect_to plans_path, notice: t(:notice_successful_delete)
      end

      private

      def find_plan
        @plan = OpenProject::CityosStrategy::StrategicPlan.find(params[:id])
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
