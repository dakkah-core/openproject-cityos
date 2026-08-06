# frozen_string_literal: true

module Cityos
  module Strategy
    class DashboardController < ApplicationController
  before_action :find_optional_project

      before_action :require_login
      before_action :authorize_global  # HEXP-0106: Strategy data is sensitive - require auth

      def show
        @active_plan = OpenProject::CityosStrategy::StrategicPlan.find_by(status: :active)
        @objectives_count = OpenProject::CityosStrategy::StrategicObjective.where(status: %i[active at_risk behind]).count
        @initiatives_active = OpenProject::CityosStrategy::StrategicInitiative.where(stage: :activated).count
        @initiatives_total = OpenProject::CityosStrategy::StrategicInitiative.count
        @metrics_stale = OpenProject::CityosStrategy::MetricDefinition.all.count { |m| m.freshness_status != "current" }
        @upcoming_reviews = OpenProject::CityosStrategy::StrategyReview.where(status: :scheduled).order(:period_start).limit(5)
      end
    end
  end
end
