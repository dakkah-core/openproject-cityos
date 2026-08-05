# frozen_string_literal: true

module Cityos
  module Strategy
    class PrioritizationController < ApplicationController
  before_action :find_optional_project

      # Prioritization matrix — scatter plot data for initiative comparison
      def show
        @initiatives = StrategicInitiative.scorable
                                          .where.not(stage: %i[closed stopped superseded])
                                          .includes(:portfolio, :owner)
                                          .order(weighted_score: :desc)

        @mandatory = StrategicInitiative.bypass_scoring
                                        .where.not(stage: %i[closed stopped superseded])

        # Matrix axes data (for scatter chart)
        @matrix_data = @initiatives.map do |i|
          {
            id: i.initiative_id,
            title: i.title,
            x: i.value_score || 0,          # Value (horizontal)
            y: i.alignment_score || 0,       # Alignment (vertical)
            r: (i.evidence_confidence || 5) / 2,  # Bubble size = confidence
            portfolio: i.portfolio&.name,
            stage: i.stage,
            weighted_score: i.weighted_score
          }
        end

        # Ranked list with score breakdown
        @ranked = @initiatives.map do |i|
          {
            initiative_id: i.initiative_id,
            title: i.title,
            weighted_score: i.weighted_score,
            scores: {
              alignment: i.alignment_score,
              value: i.value_score,
              urgency: i.urgency_score,
              risk: i.risk_score,
              readiness: i.readiness_score,
              effort: i.effort_score,
              confidence: i.evidence_confidence
            },
            estimated_cost: i.estimated_cost,
            stage: i.stage
          }
        end
      end

      # Re-rank with current scoring weights
      def rescore
        scorer = ScoringService.new
        StrategicInitiative.scorable.find_each do |i|
          i.update!(weighted_score: scorer.score(i))
        end
        redirect_to prioritization_path, notice: "All initiatives rescored"
      end
    end
  end
end
