require 'uri'

module OpenProject
  module CityosIdentity
    # ZITADEL OIDC OmniAuth Strategy
    #
    # Provides SSO login for human operators through ZITADEL.
    # Falls back to Keycloak OIDC if ZITADEL is not configured.
    #
    # Env vars:
    #   CITYOS_OIDC_ISSUER        — ZITADEL or Keycloak issuer URL
    #   CITYOS_OIDC_CLIENT_ID     — OIDC client ID
    #   CITYOS_OIDC_CLIENT_SECRET — OIDC client secret
    #   CITYOS_OIDC_REDIRECT_URI  — Callback URL (default: http://localhost:3199/auth/cityos_oidc/callback)
    class OidcStrategy
      OIDC_SCOPES = %i[openid profile email cityos_roles cityos_groups cityos_tenant].freeze

      def self.client_options
        issuer_uri = URI.parse(ENV.fetch('CITYOS_OIDC_ISSUER'))

        {
          identifier: ENV.fetch('CITYOS_OIDC_CLIENT_ID'),
          secret: ENV.fetch('CITYOS_OIDC_CLIENT_SECRET'),
          redirect_uri: ENV.fetch('CITYOS_OIDC_REDIRECT_URI', 'http://localhost:3199/auth/cityos_oidc/callback'),
          scheme: issuer_uri.scheme,
          host: issuer_uri.host,
          port: issuer_uri.port || (issuer_uri.scheme == 'https' ? 443 : 80),
          authorization_endpoint: issuer_uri.to_s + '/oauth/v2/authorize',
          token_endpoint: issuer_uri.to_s + '/oauth/v2/token',
          userinfo_endpoint: issuer_uri.to_s + '/oidc/v1/userinfo',
          jwks_uri: issuer_uri.to_s + '/oauth/v2/keys'
        }
      end

      # Register the OIDC provider with OmniAuth
      def self.register!(app)
        return unless configured?

        app.config.middleware.use OmniAuth::Builder do
          provider :openid_connect, {
            name: :cityos_oidc,
            issuer: ENV.fetch('CITYOS_OIDC_ISSUER'),
            scope: OIDC_SCOPES,
            client_options: client_options,
            response_type: :code,
            discovery: false,
            send_scope_to_token_endpoint: true,
            client_auth_method: :basic
          }
        end
      end

      def self.configured?
        ENV['CITYOS_OIDC_CLIENT_ID'].present? &&
          ENV['CITYOS_OIDC_CLIENT_SECRET'].present? &&
          ENV['CITYOS_OIDC_ISSUER'].present?
      end

      # OIDC callback handler — creates or updates the user from claims
      def self.handle_callback(auth_hash)
        user_info = auth_hash[:info]
        raw_info = auth_hash[:extra][:raw_info] rescue {}
        credentials = auth_hash[:credentials]

        OpenProject::CityosIdentity::JitProvisioner.provision(
          external_id: auth_hash[:uid],
          email: user_info[:email],
          first_name: user_info[:first_name] || raw_info['given_name'],
          last_name: user_info[:last_name] || raw_info['family_name'],
          groups: Array(raw_info['cityos_groups']),
          roles: Array(raw_info['cityos_roles']),
          tenant: raw_info['cityos_tenant'],
          id_token: credentials[:id_token]
        )
      end
    end
  end
end
