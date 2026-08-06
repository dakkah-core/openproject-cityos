module Cityos
  module Portfolio
    # Portfolio controller — program hierarchy, system views, rollups.
    class PortfolioController < ::ApplicationController
      before_action :require_login
  no_authorization_required! :index, :systems, :rollups, :system_graph, :team_planner, :metrics

      layout 'admin' rescue nil

      # GET /cityos/portfolio
      def index
        @rollup = []
        @stale = []
        @release_gates = {}
        @blocked = {}
      end

      # GET /cityos/portfolio/systems
      def systems
        @by_system = {}
        @dependency_graph = {}
        @unresolved = []
      end

      # GET /cityos/portfolio/rollups
      def rollups
        @by_proof = {}
        @by_maturity = {}
        @blocked = {}
        @stale_count = 0
      end

      # GET /cityos/portfolio/system_graph
      def system_graph
        @graph = OpenProject::CityosPortfolio::DependencyView.build_graph
        render json: @graph
      end

      # POST /cityos/portfolio/generate
      def generate
        results = OpenProject::CityosPortfolio::HierarchyGenerator.generate!(dry_run: false)
        render json: { generated: results.count, projects: results }
      end

      # ── P2.1 Optional Capabilities ──────────────────────

      # GET /cityos/portfolio/calendar.ics
      def calendar
        ical = OpenProject::CityosPortfolio::CalendarExport.generate_ical
        render plain: ical, content_type: 'text/calendar; charset=utf-8',
               headers: { 'Content-Disposition' => 'inline; filename="cityos-helm-milestones.ics"' }
      end

      # GET /cityos/portfolio/team_planner
      def team_planner
        @agent_load = []
        @sprint = []
      end

      # GET /cityos/portfolio/metrics
      def metrics
        @spi_by_system = {}
      end

      # GET /cityos/portfolio/pedd_entities?work_package_id=123
      def pedd_entities
        @entities = OpenProject::CityosPortfolio::PeddIntegration
          .query_related_entities(params[:work_package_id].to_i)
        render json: @entities
      end

      # GET /cityos/portfolio/enriched_graph
      def enriched_graph
        op_graph = OpenProject::CityosPortfolio::DependencyView.build_graph
        @graph = OpenProject::CityosPortfolio::PeddIntegration.enrich_dependency_graph(op_graph)
        render json: @graph
      end
    end
  end
end
