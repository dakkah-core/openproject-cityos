module OpenProject
  module CityOSPortfolio
    # Release-Gate Posture Dashboard
    #
    # Aggregates the state of all UCL release gates (G0-G4) across
    # the portfolio, showing which gates are open, blocked, or
    # pending for each system.
    class ReleaseGateDashboard
      GATES = %w[G0 G1 G2 G3 G4].freeze

      # Current posture across all systems and gates
      def self.current_posture
        posture = {}

        GATES.each do |gate_id|
          posture[gate_id] = { systems: {}, total: 0, blocked: 0, passed: 0 }

          OpenProject::CityOSGovernance::GovernanceProjection
            .where(gate_id: gate_id)
            .includes(:work_package)
            .find_each do |proj|
              binding = OpenProject::CityOSGovernance::ScopeBinding
                .find_by(work_package_id: proj.work_package_id)
              system_id = binding&.system_id || 'unknown'

              posture[gate_id][:systems][system_id] ||= { status: :unknown, approval_state: nil }
              posture[gate_id][:systems][system_id][:approval_state] = proj.approval_state
              posture[gate_id][:total] += 1

              case proj.approval_state
              when 'accepted'
                posture[gate_id][:passed] += 1
              when 'rejected'
                posture[gate_id][:blocked] += 1
              end
            end
        end

        posture
      end

      # Systems blocked at any gate
      def self.blocked_systems
        blocked = []
        GATES.each do |gate_id|
          OpenProject::CityOSGovernance::GovernanceProjection
            .where(gate_id: gate_id, approval_state: 'rejected')
            .find_each do |proj|
              binding = OpenProject::CityOSGovernance::ScopeBinding
                .find_by(work_package_id: proj.work_package_id)
              blocked << {
                system_id: binding&.system_id || 'unknown',
                gate_id: gate_id,
                work_package_id: proj.work_package_id,
                owner_lane: proj.owner_lane
              }
            end
        end
        blocked
      end

      # Simple gate readiness summary
      def self.summary
        posture = current_posture

        GATES.map do |gate_id|
          gate = posture[gate_id]
          {
            gate: gate_id,
            systems_count: gate[:systems].size,
            total_work_packages: gate[:total],
            passed: gate[:passed],
            blocked: gate[:blocked],
            pending: gate[:total] - gate[:passed] - gate[:blocked],
            ready_percent: gate[:total] > 0 ? (gate[:passed].to_f / gate[:total] * 100).round(1) : 0
          }
        end
      end
    end
  end
end
