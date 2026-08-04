# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class ScoringService
      # Weighted 9-criterion scoring for strategic initiatives.
      # Mandatory/regulatory initiatives bypass scoring entirely.

      DEFAULT_WEIGHTS = {
        alignment: 0.25, value: 0.20, citizen_value: 0.10,
        regulatory_urgency: 0.10, risk_reduction: 0.10,
        platform_leverage: 0.10, capability_readiness: 0.05,
        time_to_value: 0.05, evidence_confidence: 0.05
      }.freeze

      def initialize(plan = nil)
        @weights = plan&.scoring_config&.symbolize_keys || DEFAULT_WEIGHTS
      end

      # Calculate weighted score for an initiative
      def score(initiative)
        return nil if initiative.bypass_scoring?

        scores = extract_scores(initiative)
        weighted = @weights.sum do |criterion, weight|
          (scores[criterion] || 0) * weight
        end

        weighted.round(1)
      end

      # Rank initiatives within a portfolio
      def rank(initiatives)
        mandatory, scorable = initiatives.partition(&:bypass_scoring?)

        ranked = scorable.sort_by { |i| -(score(i) || 0) }
        # Mandatory always first, then scored by descending weighted score
        mandatory + ranked
      end

      private

      def extract_scores(initiative)
        {
          alignment: initiative.alignment_score.to_f,
          value: initiative.value_score.to_f,
          citizen_value: 0.0, # Future: derive from benefit projections
          regulatory_urgency: initiative.mandatory? || initiative.regulatory? ? 10.0 : 0.0,
          risk_reduction: initiative.risk_score.to_f,
          platform_leverage: 0.0, # Future: derive from linked capability count
          capability_readiness: initiative.readiness_score.to_f,
          time_to_value: (10.0 - initiative.effort_score.to_f).clamp(0, 10),
          evidence_confidence: initiative.evidence_confidence.to_f
        }
      end
    end
  end
end
