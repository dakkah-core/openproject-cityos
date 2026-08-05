module Cityos
  module Governance
    # API controller — read-only governance data for work packages.
    # Write endpoints restricted to the sync identity by WriteGuard.
    class GovernanceController < ::ApplicationController
      no_authorization_required! :show, :sync_bindings, :sync_projections
  before_action :require_login
      no_authorization_required! :show, :sync_bindings, :sync_projections
  before_action :find_work_package, except: [:show]
      no_authorization_required! :show, :sync_bindings, :sync_projections
  before_action :reject_non_sync_writes, only: [:sync_bindings, :sync_projections]

      # GET /projects/:project_id/cityos/governance (HTML) or
      # GET /api/v3/work_packages/:id/cityos_governance (JSON)
      def show
        respond_to do |format|
          format.html do
            @project = Project.find(params[:project_id])
            render layout: "angular/angular"
          end
          format.json do
            render json: {
              scope_binding: serialized_binding,
              governance_projection: serialized_projection,
              evidence_links: serialized_evidence,
              sync_receipts: serialized_receipts,
              available_commands: available_commands
            }
          end
        end
      end

      # POST /api/v3/work_packages/:id/cityos_governance/sync_bindings
      def sync_bindings
        binding = OpenProject::CityosGovernance::ScopeBinding
          .find_or_initialize_by(work_package_id: @work_package.id)

        receipt = perform_sync('scope_binding', binding, sync_binding_params) do
          binding.update!(sync_binding_params.merge(synced_at: Time.current))
        end

        render json: { receipt: receipt.as_json }
      end

      # POST /api/v3/work_packages/:id/cityos_governance/sync_projections
      def sync_projections
        projection = OpenProject::CityosGovernance::GovernanceProjection
          .find_or_initialize_by(work_package_id: @work_package.id)

        receipt = perform_sync('governance_projection', projection, sync_projection_params) do
          projection.update!(sync_projection_params.merge(projected_at: Time.current))
        end

        render json: { receipt: receipt.as_json }
      end

      private

      def find_work_package
        @work_package = WorkPackage.find(params[:work_package_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Work package not found' }, status: :not_found
      end

      def reject_non_sync_writes
        sync_identity = ENV['CITYOS_HELM_SYNC_IDENTITY']
        unless User.current.login == sync_identity
          render json: { error: 'Governance writes restricted to sync identity' }, status: :forbidden
        end
      end

      def perform_sync(type, record, params)
        OpenProject::CityosGovernance::SyncReceipt.create!(
          operation: record.persisted? ? 'update' : 'create',
          target_type: type,
          target_id: record.id,
          before_hash: record.persisted? ? Digest::SHA256.hexdigest(record.attributes.to_json) : nil,
          correlation_id: request.headers['X-Cityos-Correlation-Id'],
          actor_id: User.current.login,
          result: 'success',
          source_revision: params[:source_revision]
        ).tap { yield if block_given? }
      rescue StandardError => e
        OpenProject::CityosGovernance::SyncReceipt.create!(
          operation: 'update',
          target_type: type,
          target_id: record.id,
          result: 'error',
          error_detail: e.message,
          correlation_id: request.headers['X-Cityos-Correlation-Id'],
          actor_id: User.current.login
        )
        raise
      end

      def serialized_binding
        b = OpenProject::CityosGovernance::ScopeBinding.find_by(work_package_id: @work_package.id)
        b&.as_json
      end

      def serialized_projection
        p = OpenProject::CityosGovernance::GovernanceProjection.find_by(work_package_id: @work_package.id)
        p&.as_json
      end

      def serialized_evidence
        OpenProject::CityosGovernance::EvidenceLink
          .where(work_package_id: @work_package.id)
          .order(produced_at: :desc)
          .map(&:as_json)
      end

      def serialized_receipts
        OpenProject::CityosGovernance::SyncReceipt
          .where(target_id: @work_package.id)
          .order(created_at: :desc)
          .limit(20)
          .map(&:as_json)
      end

      def available_commands
        OpenProject::CityosFoundation::CommandDispatch.available_for(
          user: User.current,
          work_package: @work_package
        )
      end

      def sync_binding_params
        params.permit(
          :external_id, :scope_node_id, :work_item_id, :agent_task_id,
          :system_id, :capability_id, :journey_id, :experience_contract_id,
          :country_cell, :city_node, :tenant_scope,
          :source_repository, :source_revision, :source_hash
        )
      end

      def sync_projection_params
        params.permit(
          :ucl_status, :design_maturity, :runtime_maturity, :product_maturity,
          :proof_status, :target_runtime_proof_status, :approval_ref, :approval_state,
          :owner_lane, :gate_id, :release_claim_allowed,
          :source_revision, :projection_hash
        )
      end
    end
  end
end
