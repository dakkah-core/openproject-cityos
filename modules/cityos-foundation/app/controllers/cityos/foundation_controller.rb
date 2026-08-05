# frozen_string_literal: true

module Cityos
  module Foundation
    class FoundationController < ::ApplicationController
      before_action :require_login
      no_authorization_required! :index

      def index
        @active_projects = Project.visible.count
        @active_users = User.active.count
        @strategy_plans = if OpenProject.const_defined?(:CityosStrategy)
                            OpenProject::CityosStrategy::StrategicPlan.count
                          else
                            0
                          end
      rescue StandardError => e
        Rails.logger.error("[CityOS Foundation] dashboard load failure: #{e.message}")
        @active_projects = 0
        @active_users = 0
        @strategy_plans = 0
        flash.now[:warning] = "Foundation dashboard is temporarily unavailable."
      end
    end
  end
end

