# frozen_string_literal: true

# Wave 4 W4-3 (2026-08-07): governed strategy pack import endpoint.
#
#   POST /api/v1/strategy/imports
#     body: { mode: "dry-run|apply-draft|verify|export",
#             payload: { records: [...] } }
#
# Auth: requires the standard ApiAuthorization concern with
# scope=strategy-import. Wave 1 W1-4 introduced the concern; this
# controller opts into the strategy-import scope specifically.
#
# Every call returns a StrategyImportReceipt (audit evidence). Failures
# still create a receipt with status=failed so operators can see what
# went wrong without needing log access.
module Cityos
  module Strategy
    module API
      module V1
        class ImportsController < ApplicationController
          skip_before_action :verify_authenticity_token
          include Cityos::Strategy::ApiAuthorization
          requires_api_scope "strategy.import"

          def create
            mode = params[:mode].to_s
            payload = params[:payload]&.to_unsafe_h || {}

            receipt = Cityos::Strategy::Importer.run(
              payload: payload,
              mode: mode,
              actor: current_user,
              actor_scope: "strategy.import",
              source_path: params[:source_path].presence || "<http>"
            )

            render json: serialize_receipt(receipt), status: :created
          rescue Cityos::Strategy::Importer::UnsupportedMode => e
            render json: { error: "unsupported_mode", detail: e.message }, status: :bad_request
          rescue Cityos::Strategy::Importer::InvalidPayload => e
            render json: { error: "invalid_payload", detail: e.message }, status: :unprocessable_entity
          rescue => e
            Rails.logger.error("[strategy-imports] #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
            render json: { error: "import_failed", detail: e.message }, status: :internal_server_error
          end

          def show
            receipt = OpenProject::CityosStrategy::StrategyImportReceipt.find_by!(import_id: params[:id])
            render json: serialize_receipt(receipt)
          end

          def index
            receipts = OpenProject::CityosStrategy::StrategyImportReceipt.order(created_at: :desc).limit(50)
            render json: {
              receipts: receipts.map { |r| serialize_receipt(r) },
              count: receipts.count
            }
          end

          private

          def serialize_receipt(r)
            {
              import_id: r.import_id,
              source_path: r.source_path,
              source_hash: r.source_hash,
              mode: r.mode,
              status: r.status,
              dry_run: r.dry_run,
              applied_at: r.applied_at&.iso8601,
              record_deltas: r.record_deltas,
              verdicts: r.verdicts,
              error_message: r.error_message,
              actor_id: r.actor_id,
              actor_scope: r.actor_scope,
              correlation_id: r.correlation_id,
              created_at: r.created_at.iso8601
            }
          end
        end
      end
    end
  end
end
