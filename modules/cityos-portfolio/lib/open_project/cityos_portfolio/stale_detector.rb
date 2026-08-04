module OpenProject
  module CityosPortfolio
    # Detects work packages that have not been updated within a
    # configurable threshold. Useful for identifying abandoned or
    # stuck work that needs attention.
    class StaleDetector
      DEFAULT_THRESHOLD = ENV.fetch('CITYOS_STALE_THRESHOLD_DAYS', 14).to_i.days

      # Count stale work packages by status
      def self.count_stale(threshold: DEFAULT_THRESHOLD)
        stale_date = threshold.ago.to_date

        stale_wps = WorkPackage
          .where.not(status_id: Status.where(name: %w[Done Cancelled]).select(:id))
          .where('updated_at < ?', stale_date)

        {
          threshold_days: threshold / 1.day,
          stale_date: stale_date,
          total: stale_wps.count,
          by_status: stale_wps.group(:status_id).count.transform_keys { |sid|
            Status.find(sid)&.name || "unknown"
          },
          by_system: stale_wps.joins(
            'LEFT JOIN cityos_scope_bindings ON cityos_scope_bindings.work_package_id = work_packages.id'
          ).group('cityos_scope_bindings.system_id').count
        }
      end

      # Find specific stale work packages
      def self.find_stale(threshold: DEFAULT_THRESHOLD, limit: 50)
        stale_date = threshold.ago.to_date

        WorkPackage
          .where.not(status_id: Status.where(name: %w[Done Cancelled]).select(:id))
          .where('updated_at < ?', stale_date)
          .order(updated_at: :asc)
          .limit(limit)
          .map do |wp|
            {
              id: wp.id,
              subject: wp.subject,
              status: wp.status&.name,
              updated_at: wp.updated_at,
              days_stale: (Date.current - wp.updated_at.to_date).to_i,
              assigned_to: wp.assigned_to&.name || 'Unassigned'
            }
          end
      end
    end
  end
end
