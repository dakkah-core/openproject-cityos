module Cityos
  module Identity
    # OIDC Sessions Controller
    #
    # Handles:
    #   GET  /auth/cityos_oidc/callback — OIDC callback after successful login
    #   GET  /auth/cityos_oidc/failure  — OIDC authentication failure
    #   DELETE /auth/cityos_oidc/logout — Session logout with revocation
    class SessionsController < ::AccountController
      # OIDC callback and failure are unauthenticated endpoints
      skip_before_action :authorization_check_required, raise: false
      skip_before_action :check_if_login_required, raise: false
      skip_before_action :require_login, raise: false
      skip_before_action :verify_authenticity_token, only: [:create], raise: false

      # OIDC callback — user authenticated by ZITADEL/Keycloak
      def create
        auth_hash = request.env['omniauth.auth']

        unless auth_hash
          Rails.logger.error('[Cityos Identity] OIDC callback missing auth_hash')
          redirect_to signin_path, alert: 'Authentication failed — no response from identity provider'
          return
        end

        user = OpenProject::CityosIdentity::OidcStrategy.handle_callback(auth_hash)

        if user&.active?
          # Check session validity (revocation)
          valid, reason = OpenProject::CityosIdentity::SessionRevocation.check(user: user)
          unless valid
            Rails.logger.warn("[Cityos Identity] Session rejected for #{user.login}: #{reason}")
            redirect_to signin_path, alert: "Account is #{reason}"
            return
          end

          # Log the user in
          self.logged_user = user
          flash[:notice] = "Welcome, #{user.firstname}"

          redirect_to home_url
        else
          Rails.logger.error('[Cityos Identity] OIDC callback failed — user not created or locked')
          redirect_to signin_path, alert: 'Authentication failed — user account issue'
        end
      end

      # OIDC failure
      def failure
        error = params[:message] || 'unknown error'
        Rails.logger.error("[Cityos Identity] OIDC failure: #{error}")
        redirect_to signin_path, alert: "Authentication failed: #{error}"
      end

      # Logout — revoke session
      def destroy
        if current_user
          OpenProject::CityosIdentity::SessionRevocation.revoke(user: current_user)
          logout_user
          flash[:notice] = 'Signed out. Session revoked.'
        end

        redirect_to home_url
      end
    end
  end
end
