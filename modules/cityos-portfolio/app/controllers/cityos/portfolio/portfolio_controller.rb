module CityOS
  module Portfolio
    # Portfolio controller — program hierarchy, system views, rollups.
    class PortfolioController < ::ApplicationController
      before_action :require_login

      layout 'admin' rescue nil

      # GET /cityos/portfolio
      def index
        @rollup = OpenProject::CityOSPortfolio::RollupService.full_rollup
        @stale = OpenProject::CityOSPortfolio::StaleDetector.find_stale(limit: 20)
        @release_gates = OpenProject::CityOSPortfolio::ReleaseGateDashboard.summary
        @blocked = OpenProject::CityOSPortfolio::ReleaseGateDashboard.blocked_systems
      end

      # GET /cityos/portfolio/systems
      def systems
        @by_system = OpenProject::CityOSPortfolio::RollupService.by_system
        @dependency_graph = OpenProject::CityOSPortfolio::DependencyView.build_graph
        @unresolved = OpenProject::CityOSPortfolio::DependencyView.unresolved_dependencies
      end

      # GET /cityos/portfolio/rollups
      def rollups
        @by_proof = OpenProject::CityOSPortfolio::RollupService.by_proof_status
        @by_maturity = OpenProject::CityOSPortfolio::RollupService.by_maturity
        @blocked = OpenProject::CityOSPortfolio::RollupService.blocked_by_owner
        @stale_count = OpenProject::CityOSPortfolio::StaleDetector.count_stale
      end

      # GET /cityos/portfolio/system_graph
      def system_graph
        @graph = OpenProject::CityOSPortfolio::DependencyView.build_graph
        render json: @graph
      end

      # POST /cityos/portfolio/generate
      def generate
        results = OpenProject::CityOSPortfolio::HierarchyGenerator.generate!(dry_run: false)
        render json: { generated: results.count, projects: results }
      end
    end
  end
end
