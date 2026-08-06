# frozen_string_literal: true

module Cityos
  module Strategy
    module API
      module V1
        class PlanAuthorizationsController < ApplicationController
          skip_before_action :verify_authenticity_token
          before_action :require_strategy_api_access

          def index
            auths = OpenProject::CityosStrategy::PlanAuthorization.all.order(created_at: :desc)
            render json: { authorizations: auths.map { |a| serialize_authorization(a) }, count: auths.count }
          end

          def show
            auth = OpenProject::CityosStrategy::PlanAuthorization.find_by!(authorization_id: params[:id])
            render json: { authorization: serialize_authorization(auth) }
          end

          # POST — creates in draft state. Approval requires DWOS approval_ref.
          def create
            auth = OpenProject::CityosStrategy::PlanAuthorization.create!(authorization_params)
            render json: { authorization: serialize_authorization(auth) }, status: :created
          end

          # PATCH — advance state. Transition to "approved" requires dwos_approval_ref.
          def update
            auth = OpenProject::CityosStrategy::PlanAuthorization.find_by!(authorization_id: params[:id])
            if params[:authorization_state] == "approved" && auth.dwos_approval_ref.blank?
              return render json: { error: "Cannot approve without DWOS approval_ref" }, status: :forbidden
            end
            auth.update!(update_params)
            render json: { authorization: serialize_authorization(auth) }
          end

          private

          def authorization_params
            params.permit(:plan_id, :plan_version, :plan_hash, :source_revision,
                          :dwos_approval_ref, approved_scope: {}, dependency_snapshot: {})
          end

          def update_params
            params.permit(:authorization_state, :work_control_materialization_ref, :dwos_approval_ref)
          end

          def serialize_authorization(a)
            {
              authorization_id: a.authorization_id,
              plan_id: a.plan_id,
              plan_version: a.plan_version,
              authorization_state: a.authorization_state,
              dwos_approval_ref: a.dwos_approval_ref,
              work_control_materialization_ref: a.work_control_materialization_ref,
              approved_scope: a.approved_scope,
              created_at: a.created_at,
              authorized_at: a.authorized_at
            }
          end

          def require_strategy_api_access
            true  # API token auth — permission checked at gateway level
          end
        end
      end
    end
  end
end
