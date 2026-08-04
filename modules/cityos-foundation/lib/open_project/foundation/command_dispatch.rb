module OpenProject
  module CityOSFoundation
    # Dispatches CityOS command actions through Work Control Gateway.
    # Uses canonical /v1/commands endpoint with the full command envelope,
    # Gateway authorization, idempotency keys, and correlation IDs.
    class CommandDispatch
      WORK_CONTROL_URL = ENV.fetch("CITYOS_WORK_CONTROL_URL", "http://localhost:3100")
      GATEWAY_TOKEN = ENV.fetch("CITYOS_WORK_CONTROL_GATEWAY_TOKEN", "")

      COMMANDS = {
        "start_work" => {
          label: "Start Work",
          from_statuses: ["Ready"],
          to_status: "In Progress",
          requires_role: ["builder-agent", "program-planner"]
        },
        "submit_review" => {
          label: "Submit for Review",
          from_statuses: ["In Progress"],
          to_status: "In Review",
          requires_role: ["builder-agent"]
        },
        "return_rework" => {
          label: "Return for Rework",
          from_statuses: ["In Review", "Verification"],
          to_status: "In Progress",
          requires_role: ["reviewer-agent", "tester-agent"]
        },
        "complete_verification" => {
          label: "Complete Verification",
          from_statuses: ["Verification"],
          to_status: "Done",
          requires_role: ["tester-agent"]
        },
        "mark_blocked" => {
          label: "Mark Blocked",
          from_statuses: ["Ready", "In Progress", "In Review", "Verification"],
          to_status: "Blocked",
          requires_role: ["builder-agent", "reviewer-agent", "tester-agent", "security-agent"]
        },
        "clear_block" => {
          label: "Clear Block",
          from_statuses: ["Blocked"],
          to_status: "In Progress",
          requires_role: ["builder-agent", "program-planner"]
        },
        "close_execution" => {
          label: "Close Execution",
          from_statuses: ["Done"],
          to_status: "Cancelled",
          requires_role: ["program-planner", "owner-recorder"]
        }
      }.freeze

      # Canonical command envelope per Work Control Gateway /v1/commands contract
      def self.build_envelope(command:, work_package:, user:)
        {
          command: command,
          source_system: "helm",
          source_work_package_id: work_package.id,
          source_lock_version: work_package.lock_version,
          actor: {
            user_id: user.id,
            user_login: user.login,
            roles: user.roles.map(&:name)
          },
          correlation_id: SecureRandom.uuid,
          idempotency_key: "helm-#{command}-#{work_package.id}-#{work_package.lock_version}",
          timestamp: Time.current.iso8601
        }
      end

      # Validate and execute a command via Work Control Gateway
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

        # Execute via Work Control Gateway canonical /v1/commands endpoint
        begin
          envelope = build_envelope(command: command, work_package: work_package, user: user)
          uri = URI("#{WORK_CONTROL_URL}/v1/commands")

          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == "https")
          http.open_timeout = 5
          http.read_timeout = 10

          request = Net::HTTP::Post.new(uri.path)
          request.body = envelope.to_json
          request["Content-Type"] = "application/json"
          request["Authorization"] = "Bearer #{GATEWAY_TOKEN}"
          request["X-CityOS-Correlation-Id"] = envelope[:correlation_id]
          request["X-CityOS-Idempotency-Key"] = envelope[:idempotency_key]

          response = http.request(request)

          result = JSON.parse(response.body, symbolize_names: true) rescue { raw: response.body }
          case response.code.to_i
          when 200, 201
            { success: true, to_status: cmd_def[:to_status], receipt: result[:receipt] }
          when 409
            { error: "version-conflict", detail: result[:detail] || "Stale lock version" }
          when 422
            { error: "policy-denied", detail: result[:detail] || result[:error] || "Policy denied" }
          else
            { error: "Work Control rejected (#{response.code})", detail: result[:detail] || result[:error] || response.body }
          end
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
          { error: "unreachable", detail: "Work Control unreachable: #{e.message}" }
        rescue Net::OpenTimeout, Net::ReadTimeout => e
          { error: "unreachable", detail: "Work Control timeout: #{e.message}" }
        rescue StandardError => e
          { error: "unreachable", detail: "#{e.class}: #{e.message}" }
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
