module OpenProject
  module CityosIdentity
    # Just-In-Time User Provisioning
    #
    # On first OIDC login (via ZITADEL or Keycloak), creates or updates
    # the OpenProject user and syncs group memberships from OIDC claims.
    #
    # Claim mapping:
    #   sub          → identity_url (external identity)
    #   email        → mail
    #   given_name   → firstname
    #   family_name  → lastname
    #   cityos_groups → OpenProject group memberships
    #   cityos_roles  → OpenProject role assignments
    class JitProvisioner
      # Provision a user from OIDC claims. Idempotent.
      def self.provision(external_id:, email:, first_name:, last_name:, groups:, roles:, tenant:, id_token: nil)
        user = find_or_create_user(external_id, email, first_name, last_name)

        # Sync group memberships from OIDC claims
        sync_groups(user, groups) if groups.any?

        # Sync role assignments
        sync_roles(user, roles) if roles.any?

        # Store id_token for session validation / revocation checks
        store_id_token(user, id_token) if id_token

        # Audit the login
        log_provision(user, external_id, groups, roles)

        user
      end

      # ── user lifecycle ────────────────────────────────────
      def self.find_or_create_user(external_id, email, first_name, last_name)
        user = User.find_by(identity_url: "cityos-oidc:#{external_id}")

        if user
          # Update profile on each login (JIT sync)
          user.update!(
            mail: email,
            firstname: first_name,
            lastname: last_name,
            consented_at: Time.current,
            admin: false # never auto-grant admin
          )
        else
          # Create new user on first login
          random_password = SecureRandom.hex(32)
          user = User.new(
            login: "cityos-#{external_id.first(20)}",
            identity_url: "cityos-oidc:#{external_id}",
            mail: email,
            firstname: first_name,
            lastname: last_name,
            password: random_password,
            password_confirmation: random_password,
            status: User.statuses[:active],
            language: I18n.default_locale.to_s,
            consented_at: Time.current,
            admin: false
          )
          user.save!
        end

        user
      end

      # ── group sync ────────────────────────────────────────
      def self.sync_groups(user, group_names)
        current_groups = user.groups.pluck(:lastname)

        # Add user to new groups from OIDC claims
        (group_names - current_groups).each do |group_name|
          group = Group.find_or_create_by!(lastname: group_name)
          user.groups << group unless user.groups.include?(group)
          Rails.logger.info("[CityOS Identity] Added #{user.login} to group #{group_name}")
        end

        # Remove user from groups not in OIDC claims (full sync)
        (current_groups - group_names).each do |group_name|
          group = Group.find_by(lastname: group_name)
          next unless group
          user.groups.delete(group)
          Rails.logger.info("[CityOS Identity] Removed #{user.login} from group #{group_name}")
        end
      end

      # ── role sync ─────────────────────────────────────────
      def self.sync_roles(user, role_names)
        role_names.each do |role_name|
          role = Role.find_by(name: role_name)
          next unless role

          unless user.roles.include?(role)
            Member.find_or_create_by!(principal: user, project: nil) do |m|
              m.roles = [role]
            end
            Rails.logger.info("[CityOS Identity] Assigned #{user.login} role #{role_name}")
          end
        end
      end

      # ── id token storage (for revocation checks) ──────────
      def self.store_id_token(user, id_token)
        # Store in user preferences for session revocation checks
        user.pref[:cityos_id_token] = id_token
        user.pref[:cityos_id_token_iat] = Time.current.to_i
        user.pref.save!
      end

      # ── audit ─────────────────────────────────────────────
      def self.log_provision(user, external_id, groups, roles)
        Rails.logger.info(
          "[CityOS Identity] JIT provisioned user=#{user.login} " \
          "external_id=#{external_id} groups=#{groups.join(',')} roles=#{roles.join(',')}"
        )
      end
    end
  end
end
