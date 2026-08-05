# frozen_string_literal: true

module Cityos
  module Strategy
    class MetricsController < ApplicationController
  before_action :find_optional_project

      before_action :find_metric, only: %i[show edit update destroy record_observation]

      def index
        @metrics = OpenProject::CityosStrategy::MetricDefinition.includes(:targets).order(:name)
      end

      def show
        @targets = @metric.targets.order(period_start: :desc)
        @observations = @metric.observations.recent.limit(50)
      end

      def new
        @metric = OpenProject::CityosStrategy::MetricDefinition.new
      end

      def create
        @metric = OpenProject::CityosStrategy::MetricDefinition.new(metric_params)
        if @metric.save
          redirect_to metric_path(@metric), notice: t(:notice_successful_create)
        else
          render :new
        end
      end

      def edit; end

      def update
        if @metric.update(metric_params)
          redirect_to metric_path(@metric), notice: t(:notice_successful_update)
        else
          render :edit
        end
      end

      def record_observation
        @metric.observations.create!(
          value: params[:value],
          target_id: params[:target_id],
          observed_at: Time.current,
          source_system: params[:source_system] || "manual",
          freshness: :current,
          confidence: params[:confidence] || :medium,
          quality_state: params[:quality_state] || :estimated
        )
        redirect_to metric_path(@metric), notice: "Observation recorded"
      end

      def destroy
        redirect_to metrics_path, notice: t(:notice_successful_delete)
      end

      private

      def find_metric
        @metric = OpenProject::CityosStrategy::MetricDefinition.find(params[:id])
      end

      def metric_params
        params.require(:metric_definition).permit(
          :metric_id, :name, :description, :formula, :unit,
          :direction, :aggregation, :frequency, :source_system,
          :framework_profile, :owner_id
        )
      end
    end
  end
end
