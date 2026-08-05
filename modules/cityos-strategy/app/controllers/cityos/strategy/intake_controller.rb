# frozen_string_literal: true

module Cityos
  module Strategy
    class IntakeController < ApplicationController
  before_action :find_optional_project

      # Initiative intake funnel — displays all stages with initiative counts
      def show
        @stages = StrategicInitiative::FUNNEL_STAGES.keys
        @initiatives_by_stage = StrategicInitiative.all.group_by(&:stage)
        @counts = @stages.index_with { |s| (@initiatives_by_stage[s] || []).size }
        @total = StrategicInitiative.count
        @scored_total = StrategicInitiative.scorable.count
        @mandatory_total = StrategicInitiative.bypass_scoring.count

        # Active stage pipeline (where work is happening)
        @active_pipeline = StrategicInitiative.where(
          stage: %i[evidence_gathering evaluated prioritized scenario_selected]
        ).includes(:portfolio, :owner).order(weighted_score: :desc)

        # Recently activated
        @recently_activated = StrategicInitiative.where(stage: :activated)
                                                 .order(updated_at: :desc).limit(10)
      end
    end
  end
end
