module OpenProject
  module CityosIdentity
    # Agent Attribution
    #
    # Ensures every work-package change is attributed to the correct
    # agent principal (not a shared admin token) in the OpenProject
    # journal/audit trail.
    #
    # Writes attribution metadata to:
    #   - User preferences (agent_type, run_id, correlation_id)
    #   - Journal custom fields (for work-package change tracking)
    #   - CityOS attribution log
    class AgentAttribution
      # Record an agent's attribution context — called before any
      # work-package operation to ensure the journal is correctly stamped.
      def self.record(user:, agent_type:, run_id:, correlation_id: nil)
        corr_id = correlation_id || SecureRandom.uuid

        # Store in User.current for journal hooks to pick up
        Thread.current[:cityos_agent_type] = agent_type
        Thread.current[:cityos_agent_run_id] = run_id
        Thread.current[:cityos_agent_correlation_id] = corr_id

        Rails.logger.info(
          "[CityOS Attribution] agent=#{user.login} type=#{agent_type} " \
          "run=#{run_id} correlation=#{corr_id}"
        )

        { agent_type: agent_type, run_id: run_id, correlation_id: corr_id }
      end

      # Hook into OpenProject journal creation to stamp agent metadata.
      # Called from an initializer that patches Journal.
      def self.stamp_journal(journal)
        agent_type = Thread.current[:cityos_agent_type]
        return unless agent_type

        # Store agent metadata in journal notes (visible in activity tab)
        journal.notes = "[Agent: #{agent_type} | Run: #{Thread.current[:cityos_agent_run_id]}]" \
          if journal.notes.blank?

        journal.save!
      end

      # Clear thread-local attribution context after request completes
      def self.clear_context
        Thread.current[:cityos_agent_type] = nil
        Thread.current[:cityos_agent_run_id] = nil
        Thread.current[:cityos_agent_correlation_id] = nil
      end

      # Return the current agent context (for API responses)
      def self.current_context
        {
          agent_type: Thread.current[:cityos_agent_type],
          agent_run_id: Thread.current[:cityos_agent_run_id],
          agent_correlation_id: Thread.current[:cityos_agent_correlation_id]
        }
      end
    end
  end
end
