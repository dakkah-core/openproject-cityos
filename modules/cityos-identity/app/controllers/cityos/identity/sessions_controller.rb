module CityOS
  module Identity
    # OIDC Sessions Controller
    #
    # Handles:
    #   GET  /auth/cityos_oidc/callback — OIDC callback after successful login
    #   GET  /auth/cityos_oidc/failure  — OIDC authentication failure
    #   DELETE /auth/cityos_oidc/logout — Session logout with revocation
    class SessionsController < ::AccountController
      skip_before_action :verify_authenticity_token, only: [:create]
      skip_before_action :require_login, only: [:create, :failure]

      # OIDC callback — user authenticated by ZITADEL/Keycloak
      def create
        auth_hash = request.env['omniauth.auth']

        unless auth_hash
          Rails.logger.error('[CityOS Identity] OIDC callback missing auth_hash')
          redirect_to signin_path, alert: 'Authentication failed — no response from identity provider'
          return
        end

        user = OpenProject::CityOSIdentity::OidcStrategy.handle_callback(auth_hash)

        if user&.active?
          # Check session validity (revocation)
          valid, reason = OpenProject::CityOSIdentity::SessionRevocation.check(user: user)
          unless valid
            Rails.logger.warn("[CityOS Identity] Session rejected for #{user.login}: #{reason}")
            redirect_to signin_path, alert: "Account is #{reason}"
            return
          end

          # Log the user in
          self.logged_user = user
          flash[:notice] = "Welcome, #{user.firstname}"

          redirect_to home_url
        else
          Rails.logger.error('[CityOS Identity] OIDC callback failed — user not created or locked')
          redirect_to signin_path, alert: 'Authentication failed — user account issue'
        end
      end

      # OIDC failure
      def failure
        error = params[:message] || 'unknown error'
        Rails.logger.error("[CityOS Identity] OIDC failure: #{error}")
        redirect_to signin_path, alert: "Authentication failed: #{error}"
      end

      # Logout — revoke session
      def destroy
        if current_user
          OpenProject::CityOSIdentity::SessionRevocation.revoke(user: current_user)
          logout_user
          flash[:notice] = 'Signed out. Session revoked.'
        end

        redirect_to home_url
      end
    end
  end
end
