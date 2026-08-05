module OpenProject
  module CityosFoundation
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
             { controller: '/cityos/foundation/dashboard', action: :index },
             caption: :"cityos.foundation.label_foundation",
             after: :settings

        # Replace enterprise dependency placeholders with CityOS alternatives.
        menu :admin_menu,
             :cityos_style,
             { controller: '/cityos/foundation/dashboard', action: :style },
             caption: :"cityos.foundation.label_style",
             after: :cityos_foundation

        # Note: revit_add_in is an existing OpenProject account menu item with an empty URL.
        # We override it here with a safe CityOS landing page.
        delete_menu_item(:account_menu, :revit_add_in) rescue nil
        menu :account_menu,
             :revit_add_in,
             { controller: '/cityos/foundation/dashboard', action: :revit_add_in },
             caption: :"cityos.foundation.label_revit_add_in",
             after: :my_profile
      end

      # ── Routes ────────────────────────────────────────────────────
      initializer "cityos_foundation.routes" do |app|
        app.routes.append do
          get "/cityos/foundation", to: "cityos/foundation/dashboard#index",
              as: :cityos_foundation_dashboard
          get "/admin/cityos/foundation", to: "cityos/foundation/dashboard#index"
          get "/cityos/foundation/revit_add_in",
              to: "cityos/foundation/dashboard#revit_add_in",
              as: :cityos_foundation_revit_add_in
          get "/cityos/foundation/style",
              to: "cityos/foundation/dashboard#style",
              as: :cityos_foundation_style
        end
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
