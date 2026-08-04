module OpenProject
  module CityOSPortfolio
    # Calculated Date Fields — SPI (Schedule Performance Index) and
    # CPI (Cost Performance Index) style metrics for work packages.
    #
    # SPI = Planned Duration / Actual Duration
    #   > 1.0 = ahead of schedule, < 1.0 = behind schedule
    #
    # These are computed fields — they are NOT stored in the DB
    # because they change as dates shift. They are calculated on read.
    class CalculatedMetrics
      # Schedule Performance Index for a single work package
      def self.spi(work_package)
        return nil unless work_package.start_date && work_package.due_date

        planned_days = (work_package.due_date - work_package.start_date).to_i
        return nil if planned_days <= 0

        actual_end = work_package.status&.is_closed? ?
          work_package.updated_at.to_date : Date.current
        actual_days = (actual_end - work_package.start_date).to_i
        actual_days = 1 if actual_days <= 0

        (planned_days.to_f / actual_days).round(3)
      end

      # Effort Performance Index — estimated hours vs actual time
      def self.epi(work_package)
        estimated = work_package.estimated_hours
        return nil unless estimated && estimated > 0

        actual = work_package.spent_hours || 0
        actual = 0.1 if actual <= 0 # avoid division by zero

        (estimated.to_f / actual).round(3)
      end

      # Days behind/ahead of schedule
      def self.schedule_variance(work_package)
        return nil unless work_package.due_date

        if work_package.status&.is_closed?
          (work_package.due_date - work_package.updated_at.to_date).to_i
        else
          (work_package.due_date - Date.current).to_i
        end
      end

      # Days since last update (staleness indicator)
      def self.days_since_update(work_package)
        (Date.current - work_package.updated_at.to_date).to_i
      end

      # Batch compute metrics for a collection
      def self.batch_metrics(work_packages)
        work_packages.map do |wp|
          {
            id: wp.id,
            subject: wp.subject,
            spi: spi(wp),
            epi: epi(wp),
            schedule_variance_days: schedule_variance(wp),
            days_stale: days_since_update(wp),
            status: wp.status&.name
          }
        end
      end

      # SPI rollup by system
      def self.spi_by_system
        results = Hash.new { |h, k| h[k] = { spi_values: [], count: 0 } }

        WorkPackage
          .where.not(start_date: nil)
          .where.not(due_date: nil)
          .find_each do |wp|
            s = spi(wp)
            next unless s

            binding = OpenProject::CityOSGovernance::ScopeBinding
              .find_by(work_package_id: wp.id)
            system_id = binding&.system_id || 'unknown'

            results[system_id][:spi_values] << s
            results[system_id][:count] += 1
          end

        results.transform_values do |data|
          values = data[:spi_values]
          {
            count: data[:count],
            avg_spi: (values.sum / values.size.to_f).round(3),
            min_spi: values.min.round(3),
            max_spi: values.max.round(3),
            ahead: values.count { |v| v >= 1.0 },
            behind: values.count { |v| v < 1.0 }
          }
        end
      end
    end
  end
end
