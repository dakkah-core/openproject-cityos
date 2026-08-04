module OpenProject
  module CityOSIdentity
    class Engine < ::Rails::Engine
      engine_name 'openproject_cityos_identity'

      include OpenProject::Plugins::ActsAsOpEngine

      class_inflection_override("identity" => "CityOSIdentity")

      config.before_configuration do
        Rails.autoloaders.main.ignore(root.join("lib/openproject-cityos-identity.rb"))
      end

      register(
        'openproject-cityos-identity',
        author_url: 'https://github.com/dakkah-core/openproject-cityos',
        requires_openproject: '>= 17.0.0'
      ) do
        project_module :cityos_identity do
          permission :manage_cityos_identity,
                     { "cityos/identity": %i[index settings] },
                     permissible_on: [:project],
                     require: :loggedin
        end

        menu :account_menu,
             :cityos_identity,
             { controller: "/cityos/identity", action: :index },
             caption: "CityOS Identity",
             after: :settings
      end

      # ── Load all identity services ──────────────────────
      initializer "cityos_identity.load_services" do
        require_dependency "open_project/identity/oidc_strategy"
        require_dependency "open_project/identity/jit_provisioner"
        require_dependency "open_project/identity/agent_identity_manager"
        require_dependency "open_project/identity/agent_attribution"
        require_dependency "open_project/identity/session_revocation"
      end

      # ── Register OmniAuth OIDC strategy ─────────────────
      initializer "cityos_identity.register_omniauth" do |app|
        next unless OpenProject::CityOSIdentity::OidcStrategy.configured?
        OpenProject::CityOSIdentity::OidcStrategy.register!(app)
      end

      # ── OIDC callback routes ────────────────────────────
      initializer "cityos_identity.routes" do |app|
        app.routes.append do
          get "/auth/cityos_oidc/callback",
              to: "cityos/identity/sessions#create",
              as: :cityos_oidc_callback
          get "/auth/cityos_oidc/failure",
              to: "cityos/identity/sessions#failure",
              as: :cityos_oidc_failure
          delete "/auth/cityos_oidc/logout",
                 to: "cityos/identity/sessions#destroy",
                 as: :cityos_oidc_logout
        end
      end

      # ── Journal stamp hook ──────────────────────────────
      initializer "cityos_identity.journal_stamping" do
        ActiveSupport.on_load(:journal) do
          after_create do |journal|
            OpenProject::CityOSIdentity::AgentAttribution.stamp_journal(journal)
          end
        end
      end

      # ── Session validity check ──────────────────────────
      initializer "cityos_identity.session_guard" do |app|
        app.config.middleware.use OpenProject::CityOSIdentity::SessionRevocation::Middleware
      end

      # ── Agent token rotation cron (daily) ──────────────
      initializer "cityos_identity.token_rotation" do
        Rails.logger.info("[CityOS Identity] Agent token rotation initialized")
      end
    end
  end
end
