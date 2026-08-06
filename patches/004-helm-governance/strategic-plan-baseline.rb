# frozen_string_literal: true

# Patch: StrategicPlan#baseline! — Replace self-verification with DWOS-bound baseline.
# Expansion-pack-01 §3: HELM must never create approval_verified_at or infer approval.
#
# Applied via: docker/entrypoint-cityos.sh (cp to config/initializers/)
# Validated by: grep -r "approval_verified_at" after patch

module CityOS
  module HelmGovernance
    module StrategicPlanBaselineFix
      def self.included(base)
        base.class_eval do
          # Override the core #baseline! method
          remove_method(:baseline!) if method_defined?(:baseline!)

          def baseline!(actor:)
            # Publish a DWOS-bound baseline command instead of self-verifying.
            # HELM prepares the baseline; DWOS creates the approval.
            dwos_payload = {
              action: "strategic_plan.baseline",
              subject: "StrategicPlan",
              subject_id: id,
              plan_name: name,
              plan_version: version,
              scope: {
                repository_id: ENV.fetch("CITYOS_REPOSITORY_ID", "openproject-cityos"),
                environment: ENV.fetch("CITYOS_ENVIRONMENT", "staging"),
              },
              actor: {
                user_id: actor.id,
                role: actor.admin? ? "governance-approver" : "planner",
              },
              source_revision: source_commit_sha,
              source_hash: Digest::SHA256.hexdigest(attributes.to_json),
            }

            # Write the DWOS command as a pending baseline — never self-approve
            update_columns(
              baseline_status: "pending-dwos-approval",
              baseline_requested_at: Time.current,
              baseline_requested_by: actor.id,
              dwos_command_payload: dwos_payload.to_json,
              # DO NOT set: approval_verified_at, approved_by, approval_ref
            )

            # Publish to CityBus for bridge sync
            publish_dwos_baseline_command(dwos_payload) if respond_to?(:publish_dwos_baseline_command)

            true
          end

          # Query: is this plan baselined (DWOS approval exists)?
          def baselined?
            approval_ref.present? && baseline_status == "approved"
          end

          # DEPRECATED: approval_verified_at is replaced by approval_ref
          # This accessor raises to catch any code still using the old field.
          def approval_verified_at
            raise CityOS::HelmGovernance::DeprecatedApprovalField,
              "approval_verified_at is deprecated. Use approval_ref + DWOS verification."
          end

          def approval_verified_at=(_val)
            raise CityOS::HelmGovernance::DeprecatedApprovalField,
              "approval_verified_at is deprecated. HELM must not self-approve."
          end
        end
      end
    end

    class DeprecatedApprovalField < StandardError; end
  end
end

# Apply the patch
Rails.application.config.after_initialize do
  if defined?(StrategicPlan)
    StrategicPlan.include(CityOS::HelmGovernance::StrategicPlanBaselineFix)
  end
rescue StandardError => e
  Rails.logger.warn("HELM Governance: StrategicPlan baseline patch failed: #{e.message}")
end
