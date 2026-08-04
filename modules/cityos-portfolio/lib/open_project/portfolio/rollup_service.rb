module OpenProject
  module CityOSPortfolio
    # Rollup views aggregating work packages across the portfolio
    # by system, capability, proof status, maturity, and gate posture.
    class RollupService
      # Work packages grouped by system (from scope_bindings)
      def self.by_system
        results = {}
        Project.where(active: true).find_each do |project|
          bindings = OpenProject::CityOSGovernance::ScopeBinding
            .joins(:work_package)
            .where(work_packages: { project_id: project.id })
            .where.not(system_id: nil)

          bindings.each do |b|
            results[b.system_id] ||= { total: 0, done: 0, work_packages: [] }
            results[b.system_id][:total] += 1
            results[b.system_id][:done] += 1 if b.work_package.status&.is_closed?
          end
        end
        results
      end

      # Work packages grouped by UCL proof status
      def self.by_proof_status
        results = Hash.new { |h, k| h[k] = { total: 0, work_packages: [] } }
        OpenProject::CityOSGovernance::GovernanceProjection
          .joins(:work_package)
          .where.not(proof_status: nil)
          .find_each do |proj|
            status = proj.proof_status || 'none'
            results[status][:total] += 1
          end
        results
      end

      # Work packages grouped by D/R/P maturity level
      def self.by_maturity
        results = {}
        OpenProject::CityOSGovernance::GovernanceProjection
          .joins(:work_package)
          .find_each do |proj|
            maturity = "D#{proj.design_maturity || '?'}/R#{proj.runtime_maturity || '?'}/P#{proj.product_maturity || '?'}"
            results[maturity] ||= { total: 0 }
            results[maturity][:total] += 1
          end
        results
      end

      # Blocked work packages by owner lane
      def self.blocked_by_owner
        results = Hash.new { |h, k| h[k] = [] }
        OpenProject::CityOSGovernance::GovernanceProjection
          .joins(:work_package)
          .where(approval_state: 'rejected')
          .or(
            OpenProject::CityOSGovernance::GovernanceProjection
              .joins(:work_package)
              .where(work_packages: { status_id: Status.find_by(name: 'Blocked')&.id })
          )
          .find_each do |proj|
            lane = proj.owner_lane || 'unassigned'
            results[lane] << proj.work_package_id
          end
        results
      end

      # Full rollup summary
      def self.full_rollup
        {
          by_system: by_system,
          by_proof_status: by_proof_status,
          by_maturity: by_maturity,
          blocked_by_owner: blocked_by_owner,
          stale_work_packages: OpenProject::CityOSPortfolio::StaleDetector.count_stale,
          release_gate_posture: OpenProject::CityOSPortfolio::ReleaseGateDashboard.current_posture
        }
      end
    end
  end
end
