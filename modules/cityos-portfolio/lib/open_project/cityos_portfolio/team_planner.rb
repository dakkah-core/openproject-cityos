module OpenProject
  module CityosPortfolio
    # Team Planner — agent capacity view showing workload by agent
    # over a configurable sprint/week period.
    #
    # Aggregates work packages assigned to each agent, grouped by
    # status (active/completed), with effort estimates where available.
    class TeamPlanner
      # Agent load summary — all active agents with WP counts
      def self.agent_load
        agents = load_agent_principals
        agent_map = agents.index_by(&:id)

        # Active work packages grouped by assignee
        active_status_ids = Status.where.not(name: %w[Done Cancelled]).select(:id)

        load = Hash.new { |h, k| h[k] = { active: 0, completed: 0, total: 0, work_packages: [] } }

        WorkPackage
          .where.not(assigned_to_id: nil)
          .includes(:status)
          .find_each do |wp|
            next unless agent_map.key?(wp.assigned_to_id)

            agent = agent_map[wp.assigned_to_id]
            key = agent.login

            load[key][:total] += 1
            if wp.status&.is_closed?
              load[key][:completed] += 1
            else
              load[key][:active] += 1
              load[key][:work_packages] << {
                id: wp.id,
                subject: wp.subject,
                status: wp.status&.name,
                type: wp.type&.name,
                due_date: wp.due_date
              }
            end
          end

        # Build agent load view
        load.map do |login, data|
          agent = agents.find { |a| a.login == login }
          {
            login: login,
            name: agent&.name || login,
            agent_type: agent&.pref&.[](:cityos_agent_type),
            active_wps: data[:active],
            completed_wps: data[:completed],
            total_wps: data[:total],
            completion_rate: data[:total] > 0 ?
              (data[:completed].to_f / data[:total] * 100).round(1) : 0,
            work_packages: data[:work_packages].sort_by { |wp| wp[:due_date] || Date.new(9999) }
          }
        end.sort_by { |a| -a[:active_wps] }
      end

      # Sprint/week summary — WPs created/completed in a date range
      def self.sprint_summary(days: 7)
        since = days.days.ago

        created = WorkPackage.where('created_at >= ?', since).count
        completed = WorkPackage
          .joins(:status)
          .where('work_packages.updated_at >= ?', since)
          .where(statuses: { is_closed: true })
          .count

        {
          period: "#{since.to_date} to #{Date.current}",
          days: days,
          created: created,
          completed: completed,
          velocity: (completed.to_f / [days, 1].max).round(1)
        }
      end

      private

      # Find all users with agent-* login pattern
      def self.load_agent_principals
        User.where('login LIKE ?', 'agent-%').where(status: User.statuses[:active])
      end
    end
  end
end
