module OpenProject
  module CityOSFoundation
    class Engine < ::Rails::Engine
      engine_name 'openproject_cityos_foundation'

      include OpenProject::Plugins::ActsAsOpEngine

      register(
        'openproject-cityos-foundation',
        author_url: 'https://github.com/dakkah-core/openproject-cityos',
        requires_openproject: '>= 17.0.0'
      ) do
        project_module :cityos_foundation do
          permission :view_cityos_foundation,
                     { 'cityos/foundation': [:index] },
                     public: true
        end

        menu :admin_menu,
             :cityos_foundation,
             { controller: '/cityos/foundation', action: :index },
             caption: 'CityOS HELM',
             icon: 'cityos-logo',
             after: :settings

        # Register CityOS locales
        initializer 'cityos_foundation.register_locales' do |app|
          app.config.i18n.load_path += Dir[File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'config', 'locales', '*.yml')]
        end
      end
    end
  end
end
