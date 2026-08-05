# frozen_string_literal: true

module Cityos
  module Strategy
    class IntakeController < ApplicationController
  before_action :find_optional_project
  no_authorization_required! :index, :show

      # Initiative intake funnel — displays all stages with initiative counts
      def show
        @stages = OpenProject::CityosStrategy::StrategicInitiative::FUNNEL_STAGES.keys
        @initiatives_by_stage = OpenProject::CityosStrategy::StrategicInitiative.all.group_by(&:stage)
        @counts = @stages.index_with { |s| (@initiatives_by_stage[s] || []).size }
        @total = OpenProject::CityosStrategy::StrategicInitiative.count
        @scored_total = OpenProject::CityosStrategy::StrategicInitiative.scorable.count
        @mandatory_total = OpenProject::CityosStrategy::StrategicInitiative.bypass_scoring.count

        # Active stage pipeline (where work is happening)
        @active_pipeline = OpenProject::CityosStrategy::StrategicInitiative.where(
          stage: %i[evidence_gathering evaluated prioritized scenario_selected]
        ).includes(:portfolio, :owner).order(weighted_score: :desc)

        # Recently activated
        @recently_activated = OpenProject::CityosStrategy::StrategicInitiative.where(stage: :activated)
                                                 .order(updated_at: :desc).limit(10)
      end
    end
  end
end
