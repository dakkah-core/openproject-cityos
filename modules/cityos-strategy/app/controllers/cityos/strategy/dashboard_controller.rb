# frozen_string_literal: true

module Cityos
  module Strategy
    class DashboardController < ApplicationController
  before_action :find_optional_project

      before_action :require_login
      no_authorization_required! :show

      def show
        @active_plan = StrategicPlan.find_by(status: :active)
        @objectives_count = StrategicObjective.where(status: %i[active at_risk behind]).count
        @initiatives_active = StrategicInitiative.where(stage: :activated).count
        @initiatives_total = StrategicInitiative.count
        @metrics_stale = MetricDefinition.all.count { |m| m.freshness_status != "current" }
        @upcoming_reviews = StrategyReview.where(status: :scheduled).order(:period_start).limit(5)
      end
    end
  end
end
