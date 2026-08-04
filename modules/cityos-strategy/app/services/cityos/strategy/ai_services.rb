# frozen_string_literal: true

# Cityos Strategy AI Services — S6.2-S6.4
# These services are called by the AI orchestration layer (PEDD/Pedd/Maestro)
# to provide evidence-grounded recommendations, detect objective overlap,
# and analyze dependency bottlenecks.
#
# Current state: service stubs with defined interfaces.
# Actual AI integration requires the AI orchestration layer to be live.

module OpenProject
  module CityosStrategy
    module AiServices
      # S6.2: Evidence-grounded initiative scoring recommendations
      # Called by AI orchestration to generate scoring rationale with confidence.
      class RecommendationService
        # Generate scoring recommendation for an initiative
        # Returns a hash with scores, rationale, and confidence per criterion.
        def recommend(initiative)
          # Stub: returns a basic recommendation based on available data.
          # Real implementation calls AI orchestration (Maestro/Pedd).
          {
            initiative_id: initiative.initiative_id,
            recommendations: {
              alignment: {
                score: initiative.alignment_score || 5.0,
                rationale: "Alignment score from manual assessment",
                confidence: initiative.evidence_confidence || 5.0,
                evidence: "Design documents and ADR references"
              },
              value: {
                score: initiative.value_score || 5.0,
                rationale: "Value assessment from benefits analysis",
                confidence: initiative.evidence_confidence || 5.0,
                evidence: "Benefit projections"
              },
              risk: {
                score: initiative.risk_score || 5.0,
                rationale: "Risk score from risk register",
                confidence: 7.0,
                evidence: "Strategic risk assessment"
              }
            },
            summary: "AI-powered scoring pending AI orchestration layer activation.",
            generated_at: Time.current.iso8601
          }
        end

        # Batch-generate recommendations for all scorable initiatives
        def recommend_all
          StrategicInitiative.scorable.map { |i| recommend(i) }
        end
      end

      # S6.3: Objective overlap detection
      # Identifies redundant or conflicting objectives across the strategy.
      class OverlapDetectionService
        # Detect overlapping objectives based on title similarity and KR overlap
        def detect_overlaps
          objectives = StrategicObjective.where.not(status: :closed)
          overlaps = []

          objectives.each_with_index do |a, i|
            objectives[(i + 1)..].each do |b|
              similarity = compute_similarity(a.title, b.title)
              next unless similarity > 0.6

              overlaps << {
                objective_a: a.objective_id,
                objective_b: b.objective_id,
                title_a: a.title,
                title_b: b.title,
                similarity: similarity.round(2),
                shared_krs: shared_key_result_terms(a, b),
                recommendation: similarity > 0.8 ? "merge" : "review"
              }
            end
          end

          overlaps.sort_by { |o| -o[:similarity] }
        end

        private

        def compute_similarity(a, b)
          # Simple Jaccard similarity on word tokens (stub)
          # Real implementation uses vector embeddings + cosine similarity
          a_tokens = a.downcase.split(/\W+/).uniq
          b_tokens = b.downcase.split(/\W+/).uniq
          intersection = (a_tokens & b_tokens).size
          union = (a_tokens | b_tokens).size
          union.zero? ? 0.0 : intersection.to_f / union
        end

        def shared_key_term_sets(a, b)
          a_terms = a.key_results.pluck(:title).map { |t| t.downcase.split(/\W+/) }.flatten.uniq
          b_terms = b.key_results.pluck(:title).map { |t| t.downcase.split(/\W+/) }.flatten.uniq
          (a_terms & b_terms)
        end
      end

      # S6.4: Dependency bottleneck analysis
      # Identifies critical path bottlenecks across initiative dependencies.
      class BottleneckAnalysisService
        # Analyze the dependency graph for bottlenecks
        def analyze
          deps = StrategicDependency.where(status: %i[identified active])
          initiatives = StrategicInitiative.where.not(stage: %i[closed stopped superseded])

          # Build dependency graph
          graph = build_graph(deps, initiatives)

          # Find critical path (longest chain of blocking dependencies)
          critical_path = find_critical_path(graph)

          # Find most-blocked initiatives
          blocked_counts = compute_blocked_counts(deps)

          # Find orphaned initiatives (no objectives linked)
          orphaned = find_orphaned(initiatives)

          {
            critical_path: critical_path,
            bottlenecks: blocked_counts.sort_by { |_, v| -v }.first(10).to_h,
            orphaned_initiatives: orphaned.map { |i| i.initiative_id },
            total_nodes: graph.size,
            total_edges: deps.count,
            analysis_timestamp: Time.current.iso8601
          }
        end

        private

        def build_graph(deps, initiatives)
          graph = {}
          initiatives.each { |i| graph[i.initiative_id] = [] }
          deps.each do |d|
            from = d.from_initiative&.initiative_id
            to = d.to_initiative&.initiative_id
            next unless from && to
            graph[from] ||= []
            graph[from] << to
          end
          graph
        end

        def find_critical_path(graph)
          # Find the longest simple path (stub — real impl uses topological sort + DP)
          longest = []
          graph.each_key do |node|
            path = dfs_longest(node, graph, {}, [])
            longest = path if path.size > longest.size
          end
          longest
        end

        def dfs_longest(node, graph, visited, path)
          return path if visited[node]
          visited[node] = true
          path = path + [node]
          (graph[node] || []).map { |n| dfs_longest(n, graph, visited.dup, path) }
                .max_by(&:size) || path
        end

        def compute_blocked_counts(deps)
          counts = Hash.new(0)
          deps.each { |d| counts[d.to_initiative&.initiative_id] += 1 if d.to_initiative }
          counts
        end

        def find_orphaned(initiatives)
          initiatives.reject { |i| i.objectives.any? }
        end
      end
    end
  end
end
