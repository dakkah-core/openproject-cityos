module OpenProject
  module CityosPortfolio
    # Generates the CityOS portfolio project hierarchy from canonical
    # registries (config/implementation-scope/taxonomy/ and
    # config/system-capability-registry/).
    #
    # Creates the tree:
    #   CityOS Global Program
    #   ├── Platform Engineering
    #   ├── Product & Experience
    #   ├── Core Systems (Agora, Nexus, CMS, Helm, etc.)
    #   ├── Shared Systems (domains, documents, party, policy)
    #   ├── Vertical Systems (mobility, health, commerce, etc.)
    #   ├── Infrastructure (Keycloak, Temporal, Kuzzle, etc.)
    #   ├── Security & Governance (compliance, audit, UCL)
    #   └── Release Programs (release gates, promotion)
    class HierarchyGenerator
      PORTFOLIO = {
        'cityos-global-program' => {
          name: 'CityOS Global Program',
          identifier: 'global-program',
          description: 'Root portfolio for all CityOS platform execution',
          children: {
            'platform-engineering' => {
              name: 'Platform Engineering',
              identifier: 'platform-engineering',
              description: 'Compiler fabric, PEDD, Semantic Universe, Extension fabric'
            },
            'product-experience' => {
              name: 'Product & Experience',
              identifier: 'product-experience',
              description: 'SDUI renderers, design system, Studio, surface runtimes'
            },
            'core-systems' => {
              name: 'Core Systems',
              identifier: 'core-systems',
              systems: %w[cms agora nexus tryton helm]
            },
            'shared-systems' => {
              name: 'Shared Systems',
              identifier: 'shared-systems',
              systems: %w[documents party placement policy]
            },
            'vertical-systems' => {
              name: 'Vertical Systems',
              identifier: 'vertical-systems',
              systems: %w[mobility healthcare governance commerce finance]
            },
            'infrastructure' => {
              name: 'Infrastructure',
              identifier: 'infrastructure',
              systems: %w[keycloak temporal kuzzle meilisearch minio infisical gitlab-ci]
            },
            'security-governance' => {
              name: 'Security & Governance',
              identifier: 'security-governance',
              description: 'Compliance, UCL, audit, secrets, approval chains'
            },
            'release-programs' => {
              name: 'Release Programs',
              identifier: 'release-programs',
              description: 'Release gates, promotion records, deployment evidence'
            }
          }
        }
      }.freeze

      # Generate the full hierarchy, creating projects as needed
      def self.generate!(dry_run: false)
        results = []

        PORTFOLIO.each do |root_id, root_def|
          root_project = ensure_project(root_def.merge(identifier: root_id), nil, dry_run)
          results << { project: root_def[:name], id: root_project&.id, action: 'root' }

          (root_def[:children] || {}).each do |child_id, child_def|
            child_project = ensure_project(
              child_def.merge(identifier: child_id),
              root_project,
              dry_run
            )
            results << { project: child_def[:name], id: child_project&.id, action: 'child' }

            # Create system-level sub-projects
            (child_def[:systems] || []).each do |system_id|
              sys_project = ensure_project(
                { name: system_id.capitalize, identifier: system_id },
                child_project,
                dry_run
              )
              results << { project: system_id, id: sys_project&.id, action: 'system' }
            end
          end
        end

        results
      end

      private

      def self.ensure_project(defn, parent, dry_run)
        project = Project.find_by(identifier: defn[:identifier])

        if project
          Rails.logger.debug("[Portfolio] Project exists: #{defn[:name]}")
        elsif dry_run
          Rails.logger.info("[Portfolio] Would create: #{defn[:name]}")
          return nil
        else
          project = Project.create!(
            name: defn[:name],
            identifier: defn[:identifier],
            description: defn[:description] || "CityOS #{defn[:name]}",
            parent: parent,
            is_public: false,
            status: Project.statuses[:active]
          )
          Rails.logger.info("[Portfolio] Created project: #{defn[:name]}")
        end

        project
      end
    end
  end
end
