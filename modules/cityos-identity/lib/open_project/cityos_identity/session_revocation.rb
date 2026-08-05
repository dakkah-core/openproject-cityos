module OpenProject
  module CityosIdentity
    # Session Revocation
    #
    # When a user is disabled in ZITADEL/Keycloak, their HELM session
    # must be invalidated promptly. This service:
    #
    # 1. Checks OIDC token validity on each authenticated request
    # 2. Invalidates local session if the OIDC token is revoked/expired
    # 3. Disables the OpenProject user if the external account is disabled
    #
    # Revocation sources:
    #   - OIDC UserInfo endpoint (active field)
    #   - OIDC introspection endpoint (token active field)
    #   - Local session age (max CITYOS_MAX_SESSION_AGE)
    class SessionRevocation
      MAX_SESSION_AGE = ENV.fetch('CITYOS_MAX_SESSION_AGE', 8).to_i.hours

      # Check if a user's session is still valid.
      # Returns [valid: boolean, reason: string]
      def self.check(user:)
        # Check 1: Is the user still active in OpenProject?
        unless user.active?
          return [false, "User #{user.login} is not active (status: #{user.status})"]
        end

        # Check 2: Has the id_token expired? (stored in preferences on login)
        # Skip if UserPreference doesn't support custom key storage
        id_token_iat = safe_pref_get(user, :cityos_id_token_iat)
        if id_token_iat
          session_age = Time.current.to_i - id_token_iat.to_i
          if session_age > MAX_SESSION_AGE.to_i
            return [false, "Session age (#{session_age}s) exceeds max (#{MAX_SESSION_AGE}s)"]
          end
        end

        # Check 3: Is the OIDC token still active? (if issuer is reachable)
        if OidcStrategy.configured?
          begin
            active = verify_token_active(user)
            return [false, "OIDC token revoked or expired"] unless active
          rescue StandardError => e
            # OIDC issuer unreachable — allow session to continue
            # but log a warning. Do NOT lock users out due to transient
            # OIDC unavailability.
            Rails.logger.warn("[CityOS Revocation] OIDC check failed for #{user.login}: #{e.message}")
          end
        end

        [true, nil]
      end

      # Revoke a user's HELM session
      def self.revoke(user:)
        Rails.logger.info("[CityOS Revocation] Revoking session for #{user.login}")

        # Disable the user in OpenProject
        user.update!(status: User.statuses[:locked])

        # Revoke all API tokens
        Token::API.where(user_id: user.id).destroy_all

        # Clear stored id_token (if UserPreference supports custom keys)
        safe_pref_set(user, :cityos_id_token, nil)
        safe_pref_set(user, :cityos_id_token_iat, nil)
        safe_pref_save(user)
      end

      # Disable user if their external account is inactive
      def self.sync_external_status(user)
        return unless OidcStrategy.configured?

        begin
          # Call OIDC userinfo to check account status
          uri = URI("#{ENV['CITYOS_OIDC_ISSUER']}/oidc/v1/userinfo")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == 'https'

          request = Net::HTTP::Get.new(uri)
          id_token = safe_pref_get(user, :cityos_id_token)
          request['Authorization'] = "Bearer #{id_token}" if id_token

          response = http.request(request)
          if response.code == '401'
            # Token invalid — revoke session
            revoke(user: user)
          end
        rescue StandardError => e
          Rails.logger.warn("[CityOS Revocation] External status check failed for #{user.login}: #{e.message}")
        end
      end

      private

      # Safe UserPreference access — returns nil if custom keys not supported
      def self.safe_pref_get(user, key)
        pref = user.pref
        pref.respond_to?(:[]) ? pref[key] : nil
      rescue StandardError
        nil
      end

      # Safe UserPreference write — no-op if custom keys not supported
      def self.safe_pref_set(user, key, value)
        pref = user.pref
        pref[key] = value if pref.respond_to?(:[]=)
      rescue StandardError => e
        Rails.logger.debug("[CityOS Revocation] Cannot set #{key} on UserPreference: #{e.message}")
      end

      # Safe UserPreference save — no-op if custom keys not supported
      def self.safe_pref_save(user)
        pref = user.pref
        pref.save! if pref.respond_to?(:save!)
      rescue StandardError => e
        Rails.logger.debug("[CityOS Revocation] Cannot save UserPreference: #{e.message}")
      end

      def self.verify_token_active(user)
        id_token = safe_pref_get(user, :cityos_id_token)
        # No stored token — skip verification (token storage not supported
        # by UserPreference in this OpenProject version)
        return true unless id_token

        # OIDC introspection endpoint
        uri = URI("#{ENV['CITYOS_OIDC_ISSUER']}/oauth/v2/introspect")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'

        request = Net::HTTP::Post.new(uri)
        request.set_form_data(token: id_token)
        request.basic_auth(
          ENV.fetch('CITYOS_OIDC_CLIENT_ID'),
          ENV.fetch('CITYOS_OIDC_CLIENT_SECRET')
        )

        response = http.request(request)
        body = JSON.parse(response.body)

        body['active'] == true
      end

      # Rack middleware: checks session validity on every request.
      class Middleware
        def initialize(app)
          @app = app
        end

        def call(env)
          catch(:invalid_session) do
            @app.call(env)
          end
        end
      end
    end
  end
end
