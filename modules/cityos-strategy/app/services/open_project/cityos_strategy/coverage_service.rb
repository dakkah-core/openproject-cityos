# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class CoverageService
      # Freeze a versioned baseline from the current universe state
      def self.create_baseline(universe_version:, node_set:, owner: nil)
        node_set_hash = Digest::SHA256.hexdigest(node_set.sort.join(","))
        CoverageBaseline.create!(
          baseline_id: "cov-#{SecureRandom.uuid}",
          universe_version:,
          included_node_set: node_set,
          node_set_hash:,
          owner:,
          snapshot_data: { created_from: universe_version, node_count: node_set.size }
        )
      end

      # Diff two baselines — returns added, removed, and unchanged nodes
      def self.compare_baselines(baseline_a_id, baseline_b_id)
        a = CoverageBaseline.find_by!(baseline_id: baseline_a_id)
        b = CoverageBaseline.find_by!(baseline_id: baseline_b_id)
        nodes_a = Set.new(a.included_node_set || [])
        nodes_b = Set.new(b.included_node_set || [])

        {
          baseline_a: { id: baseline_a_id, version: a.version, count: nodes_a.size },
          baseline_b: { id: baseline_b_id, version: b.version, count: nodes_b.size },
          added: (nodes_b - nodes_a).to_a,
          removed: (nodes_a - nodes_b).to_a,
          unchanged: (nodes_a & nodes_b).to_a
        }
      end

      # Compute current coverage % against a baseline
      def self.compute_coverage(baseline_id)
        baseline = CoverageBaseline.find_by!(baseline_id:)
        targets = CoverageTarget.where(baseline_id:)

        total_nodes = baseline.included_node_set&.size || 0
        return 0.0 if total_nodes.zero?

        # Count nodes that have a target with current_pct >= target_pct
        covered = targets.select(&:achieved?).size
        ((covered.to_f / total_nodes) * 100).round(1)
      end

      # Detect gaps — nodes in the baseline with no target or below-target coverage
      def self.detect_gaps(baseline_id)
        baseline = CoverageBaseline.find_by!(baseline_id:)
        targets = CoverageTarget.where(baseline_id:)
        targeted_nodes = targets.pluck(:universe_node).uniq

        {
          baseline_id:,
          total_nodes: baseline.included_node_set&.size || 0,
          targeted_nodes: targeted_nodes.size,
          untargeted: (baseline.included_node_set || []) - targeted_nodes,
          below_target: targets.reject(&:achieved?).map(&:universe_node)
        }
      end
    end
  end
end
