module OpenProject
  module CityOSPortfolio
    # Cross-system dependency view — shows relationships between
    # work packages across different CityOS systems.
    #
    # Dependencies are extracted from:
    #   - Work package relations (relates_to, blocks, precedes)
    #   - Scope bindings (system_id grouping)
    class DependencyView
      # Build a cross-system dependency graph
      def self.build_graph
        graph = { nodes: [], edges: [] }
        seen_systems = {}

        # Collect all systems from scope bindings
        OpenProject::CityOSGovernance::ScopeBinding
          .where.not(system_id: nil)
          .find_each do |binding|
            next if seen_systems[binding.system_id]
            seen_systems[binding.system_id] = true
            graph[:nodes] << {
              id: binding.system_id,
              label: binding.system_id,
              work_package_count: OpenProject::CityOSGovernance::ScopeBinding
                .where(system_id: binding.system_id).count
            }
          end

        # Collect cross-system relations
        OpenProject::CityOSGovernance::ScopeBinding
          .where.not(system_id: nil)
          .includes(work_package: :relations)
          .find_each do |binding|
            binding.work_package.relations.each do |rel|
              related_binding = OpenProject::CityOSGovernance::ScopeBinding
                .find_by(work_package_id: rel.to_id)
              next unless related_binding && related_binding.system_id
              next if related_binding.system_id == binding.system_id

              graph[:edges] << {
                from: binding.system_id,
                to: related_binding.system_id,
                type: rel.relation_type,
                work_package_ids: [binding.work_package_id, rel.to_id]
              }
            end
          end

        graph
      end

      # Find work packages that have unfulfilled dependencies
      def self.unresolved_dependencies
        unresolved = []

        WorkPackage
          .where(status_id: Status.where.not(name: %w[Done Cancelled]).select(:id))
          .includes(:relations_from)
          .find_each do |wp|
            wp.relations_from.where(relation_type: %w[blocks precedes]).each do |rel|
              target = WorkPackage.find_by(id: rel.to_id)
              next unless target && !target.status&.is_closed?

              unresolved << {
                work_package_id: wp.id,
                subject: wp.subject,
                blocked_by_id: target.id,
                blocked_by_subject: target.subject,
                blocked_by_status: target.status&.name
              }
            end
          end

        unresolved
      end
    end
  end
end
