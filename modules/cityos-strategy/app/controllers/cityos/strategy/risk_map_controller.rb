# frozen_string_literal: true

module Cityos
  module Strategy
    class RiskMapController < ApplicationController
  before_action :find_optional_project
  before_action :authorize_global  # HEXP-0106: Strategy data is sensitive - require auth

      # Strategic risk and assumption map — uncertainty visualization data
      def show
        @risks = OpenProject::CityosStrategy::StrategicRisk.includes(:initiative, :objective)
                              .where(status: :active)
                              .order(likelihood: :desc, impact: :desc)

        @assumptions = StrategicAssumption.includes(:initiative)
                                          .where(status: %i[unvalidated valid])

        # Risk heatmap data (likelihood x impact)
        @heatmap = @risks.map do |r|
          {
            id: r.id,
            description: r.description,
            initiative: r.initiative&.title,
            likelihood: r.likelihood,
            impact: r.impact,
            risk_score: r.risk_score,
            status: r.status,
            mitigation: r.mitigation
          }
        end

        # Risk by score bracket
        @critical = @risks.select { |r| r.risk_score >= 12 }
        @high = @risks.select { |r| r.risk_score.between?(6, 11) }
        @moderate = @risks.select { |r| r.risk_score < 6 }

        # Due-soon assumptions
        @due_soon = @assumptions.select { |a| a.valid_until && a.valid_until < 90.days.from_now }
      end
    end
  end
end
