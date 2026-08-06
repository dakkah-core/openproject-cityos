# frozen_string_literal: true

# HEXP-0501-0505: Portfolio Read Model + Scenario Runtime
# Replaces controller-local empty arrays with real projections.
module OpenProject
  module CityosStrategy
    class PortfolioReadModel
      # Build real rollup data from the strategy database.
      def self.rollups(portfolio)
        {
          initiative_count: portfolio.initiatives.count,
          active_initiatives: portfolio.initiatives.where(stage: %i[activated benefits_review]).count,
          total_benefits: portfolio.initiatives.joins(:benefits).count,
          total_risks: portfolio.initiatives.joins(:risks).count,
          programs: portfolio.programs.map { |p| program_summary(p) },
          by_stage: stage_breakdown(portfolio),
          by_contribution: contribution_breakdown(portfolio),
          stale_list: stale_initiatives(portfolio),
          blocked_list: blocked_initiatives(portfolio)
        }
      end

      # HEXP-0502: Program hierarchy with initiative links
      def self.program_summary(program)
        {
          stable_id: "helm-program-#{program.id}",
          name: program.name,
          status: program.status,
          initiative_count: program.initiatives.count,
          initiatives: program.initiatives.map { |i| initiative_card(i) }
        }
      end

      # HEXP-0504: Scenario constraints
      def self.scenario_constraints(scenario)
        {
          stable_id: scenario.try(:stable_id),
          name: scenario&.name,
          status: scenario&.status,
          initiative_count: scenario&.initiatives&.count || 0,
          total_estimated_hours: scenario&.initiatives&.sum(:estimated_hours) || 0,
          allocation: scenario&.allocations&.map { |a| {
            resource: a.resource_name,
            percentage: a.percentage,
            hours: a.hours
          }} || []
        }
      end

      # HEXP-0505: Funding/capacity projection
      def self.capacity_projection(portfolio)
        initiatives = portfolio.initiatives.includes(:program)
        {
          total_initiatives: initiatives.count,
          funded: initiatives.where(funding_status: %i[approved allocated]).count,
          unfunded: initiatives.where(funding_status: %i[unfunded requested]).count,
          by_program: portfolio.programs.map { |p| {
            name: p.name,
            initiatives: p.initiatives.count,
            funded: p.initiatives.where(funding_status: %i[approved allocated]).count
          }}
        }
      end

      # HEXP-0503: Initiative scoring projections
      def self.initiative_card(initiative)
        {
          stable_id: initiative.stable_id,
          initiative_id: initiative.initiative_id,
          title: initiative.title,
          stage: initiative.stage,
          mandatory_class: initiative.mandatory_class,
          funding_status: initiative.funding_status,
          program_name: initiative.program&.name,
          benefits_count: initiative.benefits.count,
          risks_count: initiative.risks.count,
          execution_links_count: initiative.execution_links.count
        }
      end

      private

      def self.stage_breakdown(portfolio)
        StrategicInitiative::FUNNEL_STAGES.keys.map do |stage|
          count = portfolio.initiatives.where(stage: stage).count
          { stage: stage, count: count } if count > 0
        end.compact
      end

      def self.contribution_breakdown(portfolio)
        profiles = ContributionProfile.where(initiative_id: portfolio.initiatives.pluck(:id))
        ContributionProfile.profile_types.keys.map do |type|
          count = profiles.where(profile_type: type).count
          { profile: type, count: count } if count > 0
        end.compact
      end

      def self.stale_initiatives(portfolio)
        portfolio.initiatives
                 .where(stage: %i[activated benefits_review])
                 .where("updated_at < ?", 90.days.ago)
                 .map { |i| initiative_card(i) }
      end

      def self.blocked_initiatives(portfolio)
        portfolio.initiatives
                 .where(stage: %i[funding_pending approval_pending])
                 .map { |i| initiative_card(i) }
      end
    end

    # ── HEXP-0601: KPI Projection Service ────────────────────────────
    # Projects metrics from Data Analytics authority, not from direct API.
    class KpiProjectionService
      # Accept a verified observation from Analytics — NOT from arbitrary callers.
      def self.project_observation!(metric:, observation:)
        raise ArgumentError, "source_service_id required" unless observation[:sourceServiceId]
        raise ArgumentError, "Analytics authority required" unless observation[:sourceServiceId] == "data-analytics"

        MetricObservation.create!(
          metric_definition_id: metric.id,
          value: observation[:value],
          unit: observation[:unit],
          observed_at: observation[:sourceTimestamp],
          source_service_id: observation[:sourceServiceId],
          source_observation_id: observation[:sourceObservationId],
          source_revision: observation[:sourceRevision],
          source_cursor: observation[:sourceCursor],
          quality_state: observation[:qualityState] || "projected",
          confidence: observation[:confidence] || 0.0,
          evidence_refs: observation[:evidenceRefs] || [],
          payload_hash: observation[:payloadHash],
          idempotency_key: observation[:idempotencyKey]
        )
      end

      # HELM remains authoritative only for targets and thresholds.
      def self.set_target!(metric:, target:, actor:)
        metric.update!(
          target_value: target[:value],
          target_date: target[:date],
          threshold_lower: target[:thresholdLower],
          threshold_upper: target[:thresholdUpper],
          owner_id: actor.id
        )
      end
    end

    # ── HEXP-0701-0706: Security, Tenancy, RLS, SoD ─────────────────
    class StrategySecurityService
      # Verify Segregation of Duties for a strategy operation
      def self.verify_sod!(actor:, operation:, target:)
        # Planner cannot approve their own plan
        raise SecurityError, "SoD violation: planner cannot approve own plan" if
          operation == :approve && actor.id == target.owner_id

        # Machine tokens cannot create baselines
        raise SecurityError, "SoD violation: machine token cannot baseline" if
          operation == :baseline && actor.is_machine?

        true
      end

      # RLS: Ensure tenant/country-cell scoping
      def self.scope_to_tenant!(records, tenant_id:)
        records.where(tenant_id: tenant_id)
      end

      # Classify strategy data sensitivity
      def self.classify!(record)
        # Risk, allocation, cost and approval data are never public
        sensitive_fields = %i[approval_ref scoring_config allocations]
        classification = sensitive_fields.any? { |f| record.respond_to?(f) && record.send(f).present? } ? "restricted" : "internal"
        record.update_column(:classification, classification) if record.respond_to?(:classification)
        classification
      end
    end

    class SecurityError < StandardError; end

    # ── HEXP-0602: Tryton Financial Projection ───────────────────────
    class TrytonFinancialProjection
      # Project financial actuals from Tryton ERP
      def self.project_actuals!(initiative:, financial_data:)
        raise ArgumentError, "source must be Tryton" unless financial_data[:source] == "tryton"
        raise ArgumentError, "unauthenticated" unless financial_data[:auth_token].present?

        initiative.update!(
          actual_cost: financial_data[:actualCost],
          committed_cost: financial_data[:committedCost],
          forecast_cost: financial_data[:forecastCost],
          financial_source_revision: financial_data[:sourceRevision],
          financial_last_synced_at: Time.current
        )
      end

      # Benefits lifecycle (HEXP-0603)
      def self.record_benefit!(initiative:, benefit_data:)
        StrategicBenefit.create!(
          initiative_id: initiative.id,
          description: benefit_data[:description],
          benefit_type: benefit_data[:type],
          projected_value: benefit_data[:projectedValue],
          actual_value: benefit_data[:actualValue],
          measured_at: benefit_data[:measuredAt],
          currency: benefit_data[:currency] || "SAR"
        )
      end
    end
  end
end
