# frozen_string_literal: true

# HEXP-0205: Work Control Command Adapter
# Emits the current Work Control command envelope.
# Replaces the incompatible HELM command dispatch.
module OpenProject
  module CityosStrategy
    class WorkControlAdapter
      SCHEMA_VERSION = "cityos.command.v1"

      # Emit a command to Work Control using the canonical envelope.
      def emit_apply_agent_task_lifecycle(
        work_package:,
        target_status:,
        correlation_id: SecureRandom.uuid
      )
        payload = build_envelope(
          command_type: "apply-agent-task-lifecycle",
          target_ids: [],
          requested_effects: ["transition agent task to #{target_status}"],
          payload: {
            sourceWorkPackageId: work_package.id,
            sourceLockVersion: work_package.lock_version,
            targetStatus: target_status
          }
        )

        publish_to_work_control(payload, correlation_id)
      end

      # HEXP-0206: Dry-run before apply
      def dry_run_apply_agent_task_lifecycle(
        work_package:,
        target_status:,
        correlation_id: SecureRandom.uuid
      )
        payload = build_envelope(
          command_type: "apply-agent-task-lifecycle",
          target_ids: [],
          requested_effects: ["transition agent task to #{target_status}"],
          payload: {
            sourceWorkPackageId: work_package.id,
            sourceLockVersion: work_package.lock_version,
            targetStatus: target_status
          },
          dry_run: true
        )

        response = publish_dry_run(payload, correlation_id)
        {
          accepted: response["accepted"],
          conflicts: response["conflicts"] || [],
          plan_hash: response["planHash"],
          receipt_id: response["receiptId"]
        }
      end

      # Emit a start_work command to Work Control
      def emit_start_work(
        work_package:,
        agent_id:,
        correlation_id: SecureRandom.uuid
      )
        payload = build_envelope(
          command_type: "start-work",
          target_ids: [agent_id],
          requested_effects: ["assign agent to work package"],
          payload: {
            sourceWorkPackageId: work_package.id,
            sourceLockVersion: work_package.lock_version,
            agentId: agent_id
          }
        )

        publish_to_work_control(payload, correlation_id)
      end

      # Emit a submit-review command to Work Control
      def emit_submit_review(
        work_package:,
        evidence_refs: [],
        correlation_id: SecureRandom.uuid
      )
        payload = build_envelope(
          command_type: "submit-review",
          target_ids: [],
          requested_effects: ["submit work package for review"],
          payload: {
            sourceWorkPackageId: work_package.id,
            sourceLockVersion: work_package.lock_version,
            evidenceRefs: evidence_refs
          }
        )

        publish_to_work_control(payload, correlation_id)
      end

      private

      def build_envelope(
        command_type:,
        target_ids:,
        requested_effects:,
        payload: {},
        dry_run: false
      )
        envelope = {
          schemaVersion: SCHEMA_VERSION,
          commandId: SecureRandom.uuid,
          commandType: command_type,
          correlationId: SecureRandom.uuid,
          tenantId: resolve_tenant_id,
          createdAt: Time.current.iso8601,
          createdBy: resolve_principal,
          authorizationId: resolve_authorization_id,
          targetIds: target_ids,
          expectedVersions: {},
          requestedEffects: requested_effects,
          idempotencyKey: SecureRandom.uuid,
          payload: payload,
          dryRunPlanHash: dry_run ? compute_payload_hash(payload) : nil
        }

        envelope
      end

      def publish_to_work_control(envelope, correlation_id)
        # Publish to NATS subject: cityos.work-control.commands
        # This is the canonical Work Control command channel.
        # Actual NATS publishing will be wired in Wave 3 (event outbox).
        {
          status: "published",
          commandId: envelope[:commandId],
          correlationId: correlation_id,
          envelope: envelope
        }
      end

      def publish_dry_run(envelope, correlation_id)
        # Dry-run: publish with dryRunPlanHash, expect plan back.
        # Actual NATS publishing wired in Wave 3.
        {
          accepted: true,
          conflicts: [],
          planHash: envelope[:dryRunPlanHash],
          receiptId: SecureRandom.uuid
        }
      end

      def compute_payload_hash(payload)
        Digest::SHA256.hexdigest(payload.to_json)
      end

      def resolve_tenant_id
        # Tenant from current request context or ZITADEL claims
        Thread.current[:cityos_tenant_id] || "default"
      end

      def resolve_principal
        # Current authenticated principal
        User.current&.id || "system"
      end

      def resolve_authorization_id
        # DWOS or policy reference — must be resolved from current governance context
        Thread.current[:cityos_authorization_id] || "pending"
      end
    end
  end
end
