module OpenProject
  module CityosGovernance
    class Engine < ::Rails::Engine
      engine_name 'openproject_cityos_governance'

      include OpenProject::Plugins::ActsAsOpEngine

      config.before_configuration do
        Rails.autoloaders.main.ignore(root.join("lib/openproject-cityos-governance.rb"))
      end

      register(
        'openproject-cityos-governance',
        author_url: 'https://github.com/dakkah-core/openproject-cityos',
        requires_openproject: '>= 17.0.0'
      ) do
        project_module :cityos_governance do
          permission :view_cityos_governance,
                     { 'cityos/governance': [:show] },
                     permissible_on: [:project],
                     public: false
          permission :manage_cityos_governance,
                     { 'cityos/governance': [:sync_bindings, :sync_projections] },
                     permissible_on: [:project],
                     require: :admin
        end

        # Governance panel — read-only tab on work packages
        menu :project_menu,
             :cityos_governance,
             { controller: '/cityos/governance', action: :show },
             caption: 'Governance',
             icon: 'cityos-governance',
             after: :work_packages
      end

      # Register governance models
      initializer "cityos_governance.load_models" do |app|
        app.config.paths["db/migrate"] << File.join(File.dirname(__FILE__), "..", "..", "db", "migrate")
      end

      # Load governance models and controller
      initializer "cityos_governance.load_classes" do
        require_dependency "open_project/cityos_governance/write_guard"
        require_dependency "open_project/cityos_governance/scope_binding"
        require_dependency "open_project/cityos_governance/governance_projection"
        require_dependency "open_project/cityos_governance/evidence_link"
        require_dependency "open_project/cityos_governance/sync_receipt"
      end

      # Register API routes for governance
      initializer "cityos_governance.routes" do |app|
        app.routes.append do
          get "/api/v3/work_packages/:work_package_id/cityos_governance",
              to: "cityos/governance/governance#show",
              as: :cityos_governance_show
          post "/api/v3/work_packages/:work_package_id/cityos_governance/sync_bindings",
               to: "cityos/governance/governance#sync_bindings",
               as: :cityos_governance_sync_bindings
          post "/api/v3/work_packages/:work_package_id/cityos_governance/sync_projections",
               to: "cityos/governance/governance#sync_projections",
               as: :cityos_governance_sync_projections
          end
        end
    end
  end
end
