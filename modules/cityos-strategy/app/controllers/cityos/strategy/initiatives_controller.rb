# frozen_string_literal: true

module Cityos
  module Strategy
    class InitiativesController < ApplicationController
  before_action :find_optional_project
  before_action :authorize_global  # HEXP-0106: Strategy data is sensitive - require auth

      before_action :find_initiative, only: %i[show edit update destroy score advance_stage]

      def index
        @initiatives = OpenProject::CityosStrategy::StrategicInitiative.includes(:portfolio, :owner)
                                          .order(weighted_score: :desc)
        @mandatory = @initiatives.select(&:bypass_scoring?)
        @scored = @initiatives.reject(&:bypass_scoring?)
      end

      def show
        @objectives = @initiative.objectives
        @benefits = @initiative.benefits
        @risks = @initiative.risks
        @execution_links = @initiative.execution_links.includes(:work_package)
      end

      def new
        @initiative = OpenProject::CityosStrategy::StrategicInitiative.new(stage: :idea)
      end

      def create
        @initiative = OpenProject::CityosStrategy::StrategicInitiative.new(initiative_params)
        if @initiative.save
          redirect_to initiative_path(@initiative), notice: t(:notice_successful_create)
        else
          render :new
        end
      end

      def edit; end

      def update
        if @initiative.update(initiative_params)
          redirect_to initiative_path(@initiative), notice: t(:notice_successful_update)
        else
          render :edit
        end
      end

      def score
        scorer = OpenProject::CityosStrategy::ScoringService.new
        weighted = scorer.score(@initiative)
        @initiative.update!(weighted_score: weighted)
        redirect_to initiative_path(@initiative), notice: "Weighted score: #{weighted}"
      end

      def advance_stage
        next_stage = params[:target_stage]
        @initiative.advance_stage!(next_stage)
        redirect_to initiative_path(@initiative), notice: "Advanced to: #{@initiative.stage}"
      end

      def destroy
        @initiative.update!(stage: :closed)
        redirect_to initiatives_path, notice: t(:notice_successful_delete)
      end

      private

      def find_initiative
        @initiative = OpenProject::CityosStrategy::StrategicInitiative.find(params[:id])
      end

      def initiative_params
        params.require(:strategic_initiative).permit(
          :initiative_id, :title, :description, :stage, :mandatory_class,
          :alignment_score, :value_score, :urgency_score, :risk_score,
          :readiness_score, :effort_score, :evidence_confidence,
          :estimated_cost, :capacity_demand, :funding_status,
          :portfolio_id, :scenario_id, :owner_id
        )
      end
    end
  end
end
