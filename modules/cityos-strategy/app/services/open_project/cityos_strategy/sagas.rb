# frozen_string_literal: true

# HEXP-0303/0304/0305/0306/0307: Temporal Saga Definitions
# These are the long-running workflow specifications for HELM strategy events.
# Temporal workers execute these sagas when triggered by CityBus events.
module OpenProject
  module CityosStrategy
    module Sagas
      # ── HEXP-0303: Strategy Baseline Saga ──────────────────────────
      # Flow: request → document → PEDD/PSEE → DWOS approval → snapshot → baseline
      class BaselineSaga
        STEPS = %i[
          request_baseline
          materialize_document
          pedd_validation
          psee_validation
          wait_dwos_approval
          verify_approval
          create_snapshot
          apply_baseline_transaction
          publish_baselined_event
        ].freeze

        # Start the saga from a baseline request event
        def self.start(plan:, actor:, correlation_id:)
          EventOutboxService.publish!(
            aggregate: plan,
            event_name: "baseline-requested",
            payload: {
              plan_stable_id: plan.stable_id,
              plan_version: plan.version,
              content_hash: plan.send(:compute_content_hash),
              actor_id: actor.id,
              requested_at: Time.current.iso8601
            },
            correlation_id: correlation_id
          )
        end

        # Called when DWOS approval event arrives (via inbox)
        def self.on_dwos_approval_created(plan:, approval:)
          plan.apply_verified_baseline!(
            approval_projection: {
              ref: approval["approvalRef"],
              subject_hash: approval["subjectHash"],
              version: approval["version"],
              source_revision: approval["sourceRevision"],
              approved_by: approval["approvedBy"],
              revoked: false
            },
            sync_identity: "temporal-baseline-saga"
          )

          EventOutboxService.publish!(
            aggregate: plan,
            event_name: "baselined",
            payload: {
              plan_stable_id: plan.stable_id,
              plan_version: plan.version,
              approval_ref: plan.approval_ref,
              baselined_at: Time.current.iso8601
            }
          )
        end
      end

      # ── HEXP-0304: Plan-to-Work Saga ───────────────────────────────
      # Flow: initiative selected → capability closure → PSEE → PEDD → DWOS → WDR → execution
      class PlanToWorkSaga
        STEPS = %i[
          initiative_selected
          authority_capability_closure
          psee_design_availability
          pedd_conformance
          dwos_execution_authorization
          work_control_materialization
          openproject_execution_binding
        ].freeze

        # Start when an initiative is selected for execution
        def self.start(initiative:, plan:, correlation_id:)
          EventOutboxService.publish!(
            aggregate: initiative,
            event_name: "initiative-selected",
            payload: {
              initiative_stable_id: initiative.stable_id,
              initiative_id: initiative.initiative_id,
              plan_stable_id: plan.stable_id,
              stage: initiative.stage,
              selected_at: Time.current.iso8601
            },
            correlation_id: correlation_id
          )
        end

        # Called when work is accepted by Work Control
        def self.on_work_accepted(initiative:, work_item:)
          EventOutboxService.publish!(
            aggregate: initiative,
            event_name: "initiative-activated",
            payload: {
              initiative_stable_id: initiative.stable_id,
              work_item_id: work_item["workItemId"],
              agent_task_ids: work_item["agentTaskIds"],
              activated_at: Time.current.iso8601
            }
          )
        end
      end

      # ── HEXP-0305: Evidence-to-Release Saga ────────────────────────
      class EvidenceToReleaseSaga
        STEPS = %i[
          evidence_submitted
          assurance_review
          ucl_gate_evaluation
          release_eligible
          extension_activation
          release_completed
        ].freeze

        def self.on_evidence_accepted(initiative:, evidence:)
          EventOutboxService.publish!(
            aggregate: initiative,
            event_name: "release-candidate-created",
            payload: {
              initiative_stable_id: initiative.stable_id,
              evidence_refs: evidence["refs"],
              accepted_at: Time.current.iso8601
            }
          )
        end
      end

      # ── HEXP-0306: Promotion/Activation Saga ───────────────────────
      class PromotionActivationSaga
        STEPS = %i[
          gate_evaluated
          lifecycle_transitioned
          extension_activated
          promotion_recorded
        ].freeze

        def self.on_lifecycle_transitioned(plan:, transition:)
          EventOutboxService.publish!(
            aggregate: plan,
            event_name: "plan-authorized",
            payload: {
              plan_stable_id: plan.stable_id,
              from_state: transition["from"],
              to_state: transition["to"],
              transitioned_at: Time.current.iso8601
            }
          )
        end
      end

      # ── HEXP-0307: Replan Saga ─────────────────────────────────────
      class ReplanSaga
        STEPS = %i[
          supersede_current
          create_new_version
          request_baseline
          wait_approval
          activate_new
        ].freeze

        def self.start(old_plan:, new_plan:, actor:, correlation_id:)
          EventOutboxService.publish!(
            aggregate: old_plan,
            event_name: "superseded",
            payload: {
              superseded_plan_stable_id: old_plan.stable_id,
              new_plan_stable_id: new_plan.stable_id,
              superseded_at: Time.current.iso8601,
              actor_id: actor.id
            },
            correlation_id: correlation_id
          )
        end
      end

      # ── HEXP-0308: Saga registry ───────────────────────────────────
      SAGA_REGISTRY = {
        "cityos.helm.strategy.baseline-requested.v1" => BaselineSaga,
        "cityos.dwos.approval.created.v1"            => BaselineSaga,
        "cityos.helm.initiative.selected.v1"          => PlanToWorkSaga,
        "cityos.workcontrol.work.accepted.v1"         => PlanToWorkSaga,
        "cityos.assurance.evidence.accepted.v1"       => EvidenceToReleaseSaga,
        "cityos.ucl.lifecycle.transitioned.v1"        => PromotionActivationSaga,
        "cityos.helm.strategy.superseded.v1"           => ReplanSaga
      }.freeze
    end
  end
end
