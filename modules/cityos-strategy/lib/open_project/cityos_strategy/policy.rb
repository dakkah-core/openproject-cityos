# frozen_string_literal: true

# CityOS Strategy Module — Role Policy Matrix
#
# Per ADR-HELM-0010: HELM may author structured planning state.
# HELM never creates approvalRef or fabricates KPI actuals.
#
# Three strategy-specific roles extend OpenProject's built-in roles:
#   Planner  — Creates and manages strategy artifacts (plans, objectives, KRs, metrics)
#   Recorder — Records observations and snapshots (read + append)
#   Auditor  — Read-only access to all strategy artifacts + governance projections

module OpenProject
  module CityosStrategy
    module Policy
      ROLE_PERMISSIONS = {
        planner: %i[
          view_strategy_dashboard
          view_strategic_plans manage_strategic_plans
          view_objectives manage_objectives
          view_initiatives manage_initiatives
          view_scenarios manage_scenarios
          view_metrics manage_metrics
          view_reviews manage_reviews
          view_benefits manage_benefits
          view_risks manage_risks
          view_dependencies manage_dependencies
          view_allocations manage_allocations
          view_decisions manage_decisions
        ],
        recorder: %i[
          view_strategy_dashboard
          view_strategic_plans
          view_objectives
          view_initiatives
          view_scenarios
          view_metrics manage_metrics
          view_reviews
          view_benefits
          view_risks
          view_dependencies
          view_allocations
          view_decisions
        ],
        auditor: %i[
          view_strategy_dashboard
          view_strategic_plans
          view_objectives
          view_initiatives
          view_scenarios
          view_metrics
          view_reviews
          view_benefits
          view_risks
          view_dependencies
          view_allocations
          view_decisions
        ]
      }.freeze

      # Separation of Duties (SoD) — enforced at controller level
      SOD_CONSTRAINTS = {
        # A Planner who scored an initiative cannot also baseline the plan
        same_actor_cannot: [
          { action_a: :score_initiative, action_b: :baseline_plan, within: :planning_cycle }
        ],
        # A Recorder cannot modify objectives (append-only)
        role_restrictions: {
          recorder: { deny: %i[manage_strategic_plans manage_objectives manage_initiatives manage_scenarios] }
        }
      }.freeze

      # Approval gating — what requires external DWOS verification
      APPROVAL_GATED_ACTIONS = %i[
        baseline_plan
        activate_initiative
        freeze_scenario
        accept_review
      ].freeze

      # HELM never creates approvalRef — these actions are blocked by design
      NEVER_ACTIONS = %i[
        create_approval_ref
        fabricate_kpi_actual
        create_governance_approval
      ].freeze

      class << self
        def permissions_for(role)
          ROLE_PERMISSIONS[role.to_sym] || []
        end

        def sod_violation?(actor_role, action, prior_actions)
          constraint = SOD_CONSTRAINTS[:same_actor_cannot].find do |c|
            c[:action_b] == action && prior_actions.include?(c[:action_a])
          end
          constraint.present?
        end

        def approval_required?(action)
          APPROVAL_GATED_ACTIONS.include?(action.to_sym)
        end

        def never_allowed?(action)
          NEVER_ACTIONS.include?(action.to_sym)
        end
      end
    end
  end
end
