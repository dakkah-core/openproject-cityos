module OpenProject
  module CityOSPortfolio
    # Links work packages to their governing strategy documents
    # (Strategy → ADR → Spec → Capability Brief → Deliverable).
    #
    # Strategy docs are identified by their external_id in
    # cityos_scope_bindings and linked to work packages via
    # custom fields.
    class StrategyLinker
      STRATEGY_DOCS = {
        'STRAT-helm' => 'docs/architecture/helm/SPEC-cityos_helm_strategy.md',
        'SPEC-helm-customization' => 'docs/architecture/helm/specs/SPEC-cityos_helm_customization_design.md',
        'SPEC-helm-distribution' => 'docs/architecture/helm/specs/SPEC-cityos_openproject_custom_distribution.md',
        'ADR-HELM-0009' => 'docs/architecture/helm/decisions/ADR-HELM-0009_CITYOS_OPENPROJECT_DISTRIBUTION.md',
        'PLAN-03-helm' => 'docs/delivery/helm/PLAN-03-cityos-openproject-custom-build.md',
        'RUN-helm' => 'docs/runbooks/CITYOS_HELM_RUNBOOK.md'
      }.freeze

      # Return strategy documents linked to a work package
      def self.linked_docs(work_package_id)
        binding = OpenProject::CityOSGovernance::ScopeBinding
          .find_by(work_package_id: work_package_id)

        return [] unless binding

        docs = []
        STRATEGY_DOCS.each do |strategy_id, path|
          if binding.external_id == strategy_id || binding.work_item_id == strategy_id
            docs << { id: strategy_id, path: path, exists: File.exist?(Rails.root.join(path)) }
          end
        end
        docs
      end

      # Find work packages linked to a specific strategy document
      def self.work_packages_for_strategy(strategy_id)
        OpenProject::CityOSGovernance::ScopeBinding
          .where(external_id: strategy_id)
          .or(OpenProject::CityOSGovernance::ScopeBinding.where(work_item_id: strategy_id))
          .includes(:work_package)
          .map(&:work_package)
      end

      # Generate the strategy-to-implementation traceability matrix
      def self.traceability_matrix
        matrix = {}
        STRATEGY_DOCS.each_key do |strategy_id|
          wps = work_packages_for_strategy(strategy_id)
          matrix[strategy_id] = {
            doc_path: STRATEGY_DOCS[strategy_id],
            work_package_count: wps.size,
            work_packages: wps.map { |wp| { id: wp.id, subject: wp.subject, status: wp.status&.name } }
          }
        end
        matrix
      end
    end
  end
end
