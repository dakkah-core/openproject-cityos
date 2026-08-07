# frozen_string_literal: true

module Cityos
  module Strategy
    module API
      module V1
        class InitiativesController < ApplicationController
          skip_before_action :verify_authenticity_token
          include Cityos::Strategy::ApiAuthorization
          requires_api_scope "strategy.read"

          def index
            render json: OpenProject::CityosStrategy::StrategicInitiative.includes(:portfolio).map { |i|
              {
                initiative_id: i.initiative_id, title: i.title, stage: i.stage,
                mandatory_class: i.mandatory_class, weighted_score: i.weighted_score,
                portfolio: i.portfolio&.name, status: i.stage
              }
            }
          end

          def show
            i = OpenProject::CityosStrategy::StrategicInitiative.find_by!(initiative_id: params[:id])
            render json: {
              initiative_id: i.initiative_id, title: i.title, description: i.description,
              stage: i.stage, mandatory_class: i.mandatory_class,
              scores: {
                alignment: i.alignment_score, value: i.value_score,
                urgency: i.urgency_score, risk: i.risk_score,
                readiness: i.readiness_score, effort: i.effort_score,
                weighted: i.weighted_score
              },
              estimated_cost: i.estimated_cost, capacity_demand: i.capacity_demand,
              funding_status: i.funding_status, owner: i.owner&.name,
              approval_ref: i.approval_ref
            }
          end

          def score
            i = OpenProject::CityosStrategy::StrategicInitiative.find_by!(initiative_id: params[:id])
            weighted = ScoringService.new.score(i)
            i.update!(weighted_score: weighted)
            render json: { initiative_id: i.initiative_id, weighted_score: weighted }
          end
        end
      end
    end
  end
end
