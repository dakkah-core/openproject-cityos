# frozen_string_literal: true

module Cityos
  module Strategy
    module API
      module V1
        class PlanAuthorizationsController < ApplicationController
          skip_before_action :verify_authenticity_token
          include Cityos::Strategy::ApiAuthorization
          requires_api_scope "strategy.authorize"

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

          # PATCH — advance state.
          #
          # Wave 2 W2-6 (2026-08-07): the prior presence-only shortcut
          # ("dwos_approval_ref nonblank ⇒ approved allowed") is DELETED.
          # The full validation set on PlanAuthorization now enforces:
          #   * plan_hash equality with plan.compute_graph_content_hash
          #   * source_revision equality with plan.updated_at.iso8601
          #   * authorized_by != plan.owner_id (SoD)
          #   * dwos_approval_ref format matches gov-*
          # `update!` will raise ActiveRecord::RecordInvalid if any fail;
          # we surface those as 422 with the model's error messages so
          # callers know exactly which check tripped.
          def update
            auth = OpenProject::CityosStrategy::PlanAuthorization.find_by!(authorization_id: params[:id])
            auth.update!(update_params)
            render json: { authorization: serialize_authorization(auth) }
          rescue ActiveRecord::RecordInvalid => e
            render json: { error: "PlanAuthorization update rejected", detail: e.record.errors.messages }, status: :unprocessable_entity
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

        end
      end
    end
  end
end
