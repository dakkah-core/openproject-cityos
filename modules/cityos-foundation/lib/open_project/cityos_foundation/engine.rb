module OpenProject
  module CityOSFoundation
    class Engine < ::Rails::Engine
      engine_name 'openproject_cityos_foundation'

      include OpenProject::Plugins::ActsAsOpEngine

      config.before_configuration do
        Rails.autoloaders.main.ignore(root.join("lib/openproject-cityos-foundation.rb"))
      end

      register(
        'openproject-cityos-foundation',
        author_url: 'https://github.com/dakkah-core/openproject-cityos',
        requires_openproject: '>= 17.0.0'
      ) do
        project_module :cityos_foundation do
          permission :view_cityos_foundation,
                     { 'cityos/foundation': [:index] },
                     permissible_on: [:project],
                     public: true
        end

        menu :admin_menu,
             :cityos_foundation,
             { controller: '/cityos/foundation', action: :index },
             caption: 'CityOS HELM',
             icon: 'cityos-logo',
             after: :settings

      end

      # Register CityOS locales
      initializer 'cityos_foundation.register_locales' do |app|
        app.config.i18n.load_path += Dir[File.join(File.dirname(__FILE__), '..', '..', 'config', 'locales', '*.yml')]
      end

      # Load CityOS seeder, SoD guard, and command dispatch
      initializer 'cityos_foundation.load_services' do |app|
        app.config.after_initialize do
          require_dependency 'open_project/cityos_foundation/seeder'
          require_dependency 'open_project/cityos_foundation/sod_guard'
          require_dependency 'open_project/cityos_foundation/command_dispatch'
        end
      end

      # Enforce SoD on work-package save
      initializer 'cityos_foundation.sod_hooks' do |app|
        ActiveSupport.on_load(:work_package) do
          # SoD enforced via GovernanceController and CommandDispatch
        end
      end
    end
  end
end
