module OpenProject
  module CityOSFoundation
    # Dispatches CityOS command actions through Work Control.
    # Each action is validated (role, lockVersion, allowed transitions)
    # before being proxied to the Work Control API.
    class CommandDispatch
      WORK_CONTROL_URL = ENV.fetch('CITYOS_WORK_CONTROL_URL', 'http://localhost:3100')

      COMMANDS = {
        'start_work' => {
          label: 'Start Work',
          from_statuses: ['Ready'],
          to_status: 'In Progress',
          requires_role: ['builder-agent', 'program-planner']
        },
        'submit_review' => {
          label: 'Submit for Review',
          from_statuses: ['In Progress'],
          to_status: 'In Review',
          requires_role: ['builder-agent']
        },
        'return_rework' => {
          label: 'Return for Rework',
          from_statuses: ['In Review', 'Verification'],
          to_status: 'In Progress',
          requires_role: ['reviewer-agent', 'tester-agent']
        },
        'complete_verification' => {
          label: 'Complete Verification',
          from_statuses: ['Verification'],
          to_status: 'Done',
          requires_role: ['tester-agent']
        },
        'mark_blocked' => {
          label: 'Mark Blocked',
          from_statuses: ['Ready', 'In Progress', 'In Review', 'Verification'],
          to_status: 'Blocked',
          requires_role: ['builder-agent', 'reviewer-agent', 'tester-agent', 'security-agent']
        },
        'clear_block' => {
          label: 'Clear Block',
          from_statuses: ['Blocked'],
          to_status: 'In Progress',
          requires_role: ['builder-agent', 'program-planner']
        },
        'close_execution' => {
          label: 'Close Execution',
          from_statuses: ['Done'],
          to_status: 'Cancelled',
          requires_role: ['program-planner', 'owner-recorder']
        }
      }.freeze

      # Validate and execute a command
      def self.dispatch(command:, user:, work_package:)
        cmd_def = COMMANDS[command]
        return { error: "Unknown command: #{command}" } unless cmd_def

        # Role check
        user_roles = user.roles.map(&:name)
        unless (cmd_def[:requires_role] & user_roles).any?
          return { error: "Role not authorized for #{command}. Required: #{cmd_def[:requires_role].join(', ')}" }
        end

        # Status transition check
        unless cmd_def[:from_statuses].include?(work_package.status.name)
          return { error: "#{command} requires status in #{cmd_def[:from_statuses].join(', ')}, got #{work_package.status.name}" }
        end

        # SoD check
        violations = SoDGuard.enforce(
          user: user,
          work_package: work_package,
          new_status: cmd_def[:to_status]
        )
        return { error: "SoD violation: #{violations.join('; ')}" } unless violations.empty?

        # Execute transition via Work Control
        begin
          response = Net::HTTP.post(
            URI("#{WORK_CONTROL_URL}/api/commands/#{command}"),
            {
              work_package_id: work_package.id,
              lock_version: work_package.lock_version,
              user_id: user.id,
              user_login: user.login
            }.to_json,
            'Content-Type' => 'application/json',
            'X-CityOS-Correlation-Id' => SecureRandom.uuid
          )

          if response.code.to_i == 200
            { success: true, to_status: cmd_def[:to_status] }
          else
            { error: "Work Control rejected: #{response.body}" }
          end
        rescue StandardError => e
          { error: "Work Control unreachable: #{e.message}" }
        end
      end

      # Return available commands for a given work package and user
      def self.available_for(user:, work_package:)
        user_roles = user.roles.map(&:name)
        current_status = work_package.status.name

        COMMANDS.filter_map do |cmd_name, cmd_def|
          next unless (cmd_def[:requires_role] & user_roles).any?
          next unless cmd_def[:from_statuses].include?(current_status)

          { id: cmd_name, label: cmd_def[:label], to_status: cmd_def[:to_status] }
        end
      end
    end
  end
end
