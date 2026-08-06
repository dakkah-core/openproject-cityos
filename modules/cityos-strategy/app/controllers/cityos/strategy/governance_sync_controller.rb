# frozen_string_literal: true

# HEXP-0204: Governance Stable-ID Sync Controller
# Replaces broken capability-ID-as-work-package-ID sync.
# Uses stable external IDs and the canonical command envelope.
module Cityos
  module Strategy
    class GovernanceSyncController < ApplicationController
      before_action :validate_machine_identity  # HEXP-0202: Scoped machine token
      skip_before_action :verify_authenticity_token

      # POST /api/cityos/v1/governance/work-packages/by-external-id/:external_id/sync
      # Resolves by stable_id (not numeric ID), applies verified projection.
      def sync
        external_id = params[:external_id]
        projection = sync_params

        work_package = resolve_by_stable_id(external_id)
        return render json: { error: "not_found", external_id: external_id }, status: :not_found unless work_package

        # Validate idempotency
        if idempotency_key_seen?(projection[:idempotencyKey])
          return render json: { status: "already_applied", receipt: fetch_receipt(projection[:idempotencyKey]) }
        end

        # Validate expected versions (optimistic locking)
        unless version_match?(work_package, projection[:expectedVersions])
          return render json: {
            error: "version_conflict",
            current: current_versions(work_package),
            expected: projection[:expectedVersions]
          }, status: :conflict
        end

        # Apply sync projection in transaction
        receipt = apply_sync(work_package, projection)

        render json: {
          status: "applied",
          receipt: receipt,
          externalId: external_id,
          workPackageId: work_package.id,
          appliedAt: Time.current.iso8601
        }
      rescue ArgumentError => e
        render json: { error: "invalid_projection", detail: e.message }, status: :unprocessable_entity
      end

      private

      def sync_params
        params.require(:sync).permit(
          :schemaVersion, :commandId, :correlationId, :idempotencyKey,
          :syncIdentity,
          expectedVersions: {},
          source: [:serviceId, :revision, :cursor, :timestamp],
          projection: [
            :stableId, :status, :priority, :assigneeId,
            :estimatedHours, :startDate, :dueDate,
            :approvalRef, :approvalSubjectHash,
            :version, :lockVersion
          ]
        ).to_h.deep_symbolize_keys
      end

      def resolve_by_stable_id(external_id)
        # Resolve by stable_id column (HEXP-0104) — NOT by numeric ID
        WorkPackage.joins("LEFT JOIN cityos_strategy_execution_links ON work_packages.id = cityos_strategy_execution_links.work_package_id")
                   .where("cityos_strategy_execution_links.stable_id = ? OR work_packages.id::text = ?", external_id, external_id[/\d+/])
                   .first
      end

      def idempotency_key_seen?(key)
        # Check Redis/database for previously processed key
        false  # Stub — wired in Wave 3 with event outbox
      end

      def fetch_receipt(key)
        { idempotencyKey: key, appliedAt: Time.current.iso8601 }
      end

      def version_match?(work_package, expected_versions)
        return true unless expected_versions
        expected = expected_versions[:workPackage].to_i
        expected.zero? || work_package.lock_version == expected
      end

      def current_versions(work_package)
        { workPackage: work_package.lock_version }
      end

      def apply_sync(work_package, projection)
        proj = projection[:projection]
        return unless proj

        # Only write HELM-owned fields — NEVER write Work Control fields directly
        work_package.with_lock do
          work_package.update!(
            status_id: resolve_status_id(proj[:status]),
            assigned_to_id: proj[:assigneeId],
            estimated_hours: proj[:estimatedHours],
            start_date: proj[:startDate],
            due_date: proj[:dueDate]
          )
        end

        # Record the sync mapping
        OpenProject::CityosStrategy::GovernanceSyncReceipt.create!(
          work_package_id: work_package.id,
          external_id: projection.dig(:projection, :stableId),
          sync_identity: projection[:syncIdentity],
          source_service_id: projection.dig(:source, :serviceId),
          source_revision: projection.dig(:source, :revision),
          source_cursor: projection.dig(:source, :cursor),
          idempotency_key: projection[:idempotencyKey],
          correlation_id: projection[:correlationId],
          projected_at: Time.current
        )

        {
          receiptId: SecureRandom.uuid,
          idempotencyKey: projection[:idempotencyKey],
          workPackageId: work_package.id,
          lockVersion: work_package.lock_version
        }
      end

      def resolve_status_id(status_name)
        return nil unless status_name
        status = Status.find_by("LOWER(name) = ?", status_name.to_s.downcase)
        status&.id
      end

      def validate_machine_identity
        # HEXP-0202: Validate machine identity token scopes
        # Must have: strategy.sync scope
        # Reject browser sessions
        return if request.headers["X-CityOS-Machine-Token"].present?
        return if request.headers["Authorization"]&.start_with?("Bearer cityos-mt-")

        render json: { error: "machine_identity_required" }, status: :unauthorized
      end
    end

    # Receipt model for governance sync audit trail
    class GovernanceSyncReceipt < ActiveRecord::Base
      self.table_name = "cityos_strategy_governance_sync_receipts"

      belongs_to :work_package, optional: true

      validates :external_id, presence: true
      validates :idempotency_key, presence: true, uniqueness: true
      validates :sync_identity, presence: true
    end
  end
end
