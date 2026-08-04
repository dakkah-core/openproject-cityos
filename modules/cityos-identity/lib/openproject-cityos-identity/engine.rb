module OpenProject
  module CityOSIdentity
    class Engine < ::Rails::Engine
      engine_name 'openproject_cityos_identity'

      include OpenProject::Plugins::ActsAsOpEngine

      register(
        'openproject-cityos-identity',
        author_url: 'https://github.com/dakkah-core/openproject-cityos',
        requires_openproject: '>= 17.0.0'
      ) do
        project_module :cityos_identity do
          permission :manage_cityos_identity,
                     { 'cityos/identity': [:index, :settings] },
                     require: :loggedin
        end

        # OmniAuth OIDC strategy
        initializer 'cityos_identity.register_omniauth' do |app|
          next unless ENV['CITYOS_OIDC_CLIENT_ID']

          app.config.middleware.use OmniAuth::Builder do
            provider :openid_connect, {
              name: :cityos_oidc,
              issuer: ENV.fetch('CITYOS_OIDC_ISSUER', 'https://zitadel.example.com'),
              scope: [:openid, :profile, :email, 'cityos_roles'],
              client_options: {
                identifier: ENV['CITYOS_OIDC_CLIENT_ID'],
                secret: ENV['CITYOS_OIDC_CLIENT_SECRET'],
                redirect_uri: ENV.fetch('CITYOS_OIDC_REDIRECT_URI', 'http://localhost:3199/auth/cityos_oidc/callback')
              }
            }
          end
        end

        menu :account_menu,
             :cityos_identity,
             { controller: '/cityos/identity', action: :index },
             caption: 'CityOS Identity',
             after: :settings
      end
    end
  end
end
