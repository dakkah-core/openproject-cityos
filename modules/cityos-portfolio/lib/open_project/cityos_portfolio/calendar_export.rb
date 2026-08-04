module OpenProject
  module CityosPortfolio
    # Calendar Integration — iCal (RFC 5545) export of milestones.
    #
    # GET /cityos/portfolio/calendar.ics
    #
    # Exports all milestones across the portfolio as an iCal feed
    # that can be subscribed to from any calendar application.
    class CalendarExport
      PRODID = '-//CityOS HELM//Milestone Calendar//EN'

      # Generate a full iCal feed of all active milestones
      def self.generate_ical
        milestones = WorkPackage
          .where(type_id: ::Type.find_by(name: 'Milestone')&.id)
          .where.not(due_date: nil)
          .where.not(status_id: Status.where(name: %w[Cancelled]).select(:id))
          .order(due_date: :asc)

        cal = ical_header

        milestones.each do |ms|
          cal << ical_event(ms)
        end

        cal << "END:VCALENDAR\r\n"
        cal
      end

      private

      def self.ical_header
        <<~ICAL
          BEGIN:VCALENDAR
          VERSION:2.0
          PRODID:#{PRODID}
          CALSCALE:GREGORIAN
          METHOD:PUBLISH
          X-WR-CALNAME:CityOS HELM Milestones
          X-WR-CALDESC:CityOS platform delivery milestones
          X-WR-TIMEZONE:Asia/Riyadh
          REFRESH-INTERVAL;VALUE=DURATION:PT1H
        ICAL
      end

      def self.ical_event(milestone)
        due = milestone.due_date
        uid = "cityos-helm-milestone-#{milestone.id}@dakkah.cityos"

        binding = OpenProject::CityOSGovernance::ScopeBinding
          .find_by(work_package_id: milestone.id)
        system_tag = binding&.system_id ? " [#{binding.system_id}]" : ''

        <<~EVENT
          BEGIN:VEVENT
          DTSTART;VALUE=DATE:#{due.strftime('%Y%m%d')}
          DTEND;VALUE=DATE:#{(due + 1.day).strftime('%Y%m%d')}
          DTSTAMP:#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}
          UID:#{uid}
          SUMMARY:#{milestone.subject}#{system_tag}
          STATUS:#{milestone.status&.name == 'Done' ? 'COMPLETED' : 'CONFIRMED'}
          CATEGORIES:Milestone
          END:VEVENT
        EVENT
      end
    end
  end
end
