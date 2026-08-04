module OpenProject
  module CityOSGovernance
    class Engine < ::Rails::Engine
      engine_name 'openproject_cityos_governance'

      include OpenProject::Plugins::ActsAsOpEngine

      register(
        'openproject-cityos-governance',
        author_url: 'https://github.com/dakkah-core/openproject-cityos',
        requires_openproject: '>= 17.0.0'
      ) do
        project_module :cityos_governance do
          permission :view_cityos_governance,
                     { 'cityos/governance': [:index, :show, :projections] },
                     public: false
          permission :manage_cityos_governance,
                     { 'cityos/governance': [:sync] },
                     require: :admin
        end

        # Governance panel — read-only tab on work packages
        menu :project_menu,
             :cityos_governance,
             { controller: '/cityos/governance', action: :index },
             caption: 'Governance',
             icon: 'cityos-governance',
             after: :work_packages

        # Register governance models
        initializer 'cityos_governance.load_models' do |app|
          app.config.paths['db/migrate'] << File.join(File.dirname(__FILE__), '..', '..', 'db', 'migrate')
        end

        # Write guards on governance tables
        initializer 'cityos_governance.write_guards' do
          require_dependency 'openproject-cityos-governance/write_guard'
        end
      end
    end
  end
end
