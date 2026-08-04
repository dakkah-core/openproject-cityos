module OpenProject
  module CityOSIdentity
    # Agent Identity Manager
    #
    # Creates and manages per-agent OpenProject principals with:
    # - Distinct user accounts (not shared admin)
    # - Per-agent API tokens with managed rotation
    # - Agent type / run ID / correlation ID attribution
    #
    # Agent naming convention:
    #   agent-<type>-<n>  e.g. agent-coder-1, agent-reviewer-2
    #
    # Token rotation:
    #   tokens expire after CITYOS_AGENT_TOKEN_TTL (default 90 days)
    #   rotation creates a new token and revokes the old one
    class AgentIdentityManager
      AGENT_TYPES = %w[
        coder reviewer tester planner researcher
        devops security docs-writer auditor
        builder-agent reviewer-agent tester-agent security-agent
        devops-agent program-planner owner-recorder
      ].freeze

      TOKEN_TTL = ENV.fetch('CITYOS_AGENT_TOKEN_TTL', 90).to_i.days

      # ── Agent Principal CRUD ──────────────────────────────
      def self.ensure_agent(agent_type:, agent_id:, agent_name:, agent_email: nil)
        login = "agent-#{agent_type}-#{agent_id}"
        email = agent_email || "agent-#{agent_type}-#{agent_id}@cityos.internal"

        user = User.find_by(login: login)

        if user
          # Update metadata
          user.update!(
            mail: email,
            firstname: agent_name,
            lastname: "[#{agent_type}]",
            status: User.statuses[:active],
            admin: false # agents are never admins
          )
        else
          random_password = SecureRandom.hex(32)
          user = User.new(
            login: login,
            identity_url: "cityos-agent:#{agent_type}-#{agent_id}",
            mail: email,
            firstname: agent_name,
            lastname: "[#{agent_type}]",
            password: random_password,
            password_confirmation: random_password,
            status: User.statuses[:active],
            language: 'en',
            admin: false,
            consented_at: Time.current
          )
          user.save!
          Rails.logger.info("[CityOS Identity] Created agent principal: #{login}")
        end

        # Auto-assign default agent role
        ensure_agent_role(user, agent_type)

        user
      end

      # ── Bulk agent principal creation ─────────────────────
      def self.ensure_agent_fleet(agents)
        agents.each do |agent|
          ensure_agent(
            agent_type: agent[:type],
            agent_id: agent[:id],
            agent_name: agent[:name],
            agent_email: agent[:email]
          )
        end
      end

      # ── Token Management ──────────────────────────────────
      def self.create_agent_token(user)
        # Revoke any existing active tokens
        revoke_all_tokens(user)

        token = Token::API.create!(
          user: user,
          action: 'api',
          expires_at: TOKEN_TTL.from_now
        )

        Rails.logger.info("[CityOS Identity] Created API token for #{user.login} (expires #{token.expires_at})")

        token.plain_value
      end

      def self.rotate_token(user)
        revoke_all_tokens(user)
        create_agent_token(user)
      end

      def self.revoke_all_tokens(user)
        Token::API.where(user_id: user.id).destroy_all
      end

      def self.rotate_all_expiring_tokens
        Token::API.where('expires_at < ?', 7.days.from_now).find_each do |token|
          create_agent_token(token.user)
          Rails.logger.info("[CityOS Identity] Rotated expiring token for #{token.user.login}")
        end
      end

      # ── Attribution ───────────────────────────────────────
      def self.set_agent_context(user:, agent_type:, run_id:, correlation_id: nil)
        user.pref[:cityos_agent_type] = agent_type
        user.pref[:cityos_agent_run_id] = run_id
        user.pref[:cityos_agent_correlation_id] = correlation_id || SecureRandom.uuid
        user.pref.save!

        OpenProject::CityOSIdentity::AgentAttribution.record(
          user: user,
          agent_type: agent_type,
          run_id: run_id,
          correlation_id: correlation_id
        )
      end

      private

      def self.ensure_agent_role(user, agent_type)
        role_name = map_agent_type_to_role(agent_type)
        role = Role.find_or_create_by!(name: role_name) do |r|
          r.assignable = true
        end

        return if user.roles.include?(role)

        Member.find_or_create_by!(principal: user, project: nil) do |m|
          m.roles = [role]
        end
      end

      def self.map_agent_type_to_role(type)
        case type
        when 'coder', 'builder-agent' then 'builder-agent'
        when 'reviewer', 'reviewer-agent' then 'reviewer-agent'
        when 'tester', 'tester-agent' then 'tester-agent'
        when 'security', 'security-agent' then 'security-agent'
        when 'devops', 'devops-agent' then 'devops-agent'
        when 'docs-writer' then 'auditor'
        when 'planner', 'program-planner' then 'program-planner'
        when 'owner-recorder' then 'owner-recorder'
        else 'builder-agent'
        end
      end
    end
  end
end
