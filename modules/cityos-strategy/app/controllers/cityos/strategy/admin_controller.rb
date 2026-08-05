# frozen_string_literal: true

module Cityos
  module Strategy
    class AdminController < ::ApplicationController
      before_action :require_login
      no_authorization_required! :index

      def index
        @active_plans = OpenProject::CityosStrategy::StrategicPlan.where(status: :active).count
        @strategy_objectives = OpenProject::CityosStrategy::StrategicObjective.count
        @active_initiatives = OpenProject::CityosStrategy::StrategicInitiative.where(stage: :activated).count
      rescue StandardError => e
        Rails.logger.error("[CityOS Strategy] admin load failure: #{e.message}")
        @active_plans = 0
        @strategy_objectives = 0
        @active_initiatives = 0
        flash.now[:warning] = "Strategy administration is temporarily unavailable. Try again after migration refresh."
      end
    end
  end
end

