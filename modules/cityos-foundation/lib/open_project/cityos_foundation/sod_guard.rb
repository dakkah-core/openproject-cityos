module OpenProject
  module CityosFoundation
    # Enforces Separation-of-Duties constraints on work-package transitions.
    class SodGuard
      SOD_RULES = [
        {
          name: 'builder-cannot-self-review',
          check: ->(user, wp) {
            return false unless wp.author_id == user.id
            return false unless wp.assigned_to_id == user.id
            true
          },
          block_transition_to: ['In Review'],
          message: 'Builder agent cannot transition own work packages to In Review'
        },
        {
          name: 'reviewer-cannot-self-verify',
          check: ->(user, wp) {
            return false unless wp.author_id == user.id
            true
          },
          block_transition_to: ['Verification'],
          message: 'Reviewer agent cannot transition own work packages to Verification'
        },
        {
          name: 'no-agent-modifies-governance',
          check: ->(user, wp) {
            sync_identity = ENV['CITYOS_HELM_SYNC_IDENTITY']
            return false if user.login == sync_identity
            # Check if the work package has governance projections
            true
          },
          block_fields: ['cityos_governance_projections', 'cityos_scope_bindings'],
          message: 'No agent can modify governance projections'
        }
      ].freeze

      # Called before work_package save to enforce SoD
      def self.enforce(user:, work_package:, new_status: nil, changed_fields: [])
        violations = []

        SOD_RULES.each do |rule|
          next unless rule[:check].call(user, work_package)

          if rule[:block_transition_to] && new_status
            if rule[:block_transition_to].include?(new_status)
              violations << rule[:message]
            end
          end

          if rule[:block_fields]
            blocked = changed_fields & rule[:block_fields]
            violations << "#{rule[:message]}: #{blocked.join(', ')}" unless blocked.empty?
          end
        end

        violations
      end
    end
  end
end
