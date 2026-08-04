module OpenProject
  module CityosPortfolio
    class Engine < ::Rails::Engine
      engine_name 'openproject_cityos_portfolio'

      include OpenProject::Plugins::ActsAsOpEngine

      config.before_configuration do
        Rails.autoloaders.main.ignore(root.join("lib/openproject-cityos-portfolio.rb"))
      end

      register(
        'openproject-cityos-portfolio',
        author_url: 'https://github.com/dakkah-core/openproject-cityos',
        requires_openproject: '>= 17.0.0'
      ) do
        project_module :cityos_portfolio do
          permission :view_cityos_portfolio,
                     { 'cityos/portfolio': [:index, :systems, :rollups, :system_graph] },
                     permissible_on: [:project],
                     public: false
          permission :manage_cityos_portfolio,
                     { 'cityos/portfolio': [:generate] },
                     permissible_on: [:project],
                     require: :loggedin
        end

        menu :top_menu,
             :cityos_portfolio,
             { controller: '/cityos/portfolio', action: :index },
             caption: 'CityOS Portfolio',
             icon: 'cityos-portfolio',
             after: :projects
      end

      # ── Load all portfolio services ─────────────────────
      initializer "cityos_portfolio.load_services" do
        require_dependency "open_project/cityos_portfolio/hierarchy_generator"
        require_dependency "open_project/cityos_portfolio/rollup_service"
        require_dependency "open_project/cityos_portfolio/strategy_linker"
        require_dependency "open_project/cityos_portfolio/dependency_view"
        require_dependency "open_project/cityos_portfolio/stale_detector"
        require_dependency "open_project/cityos_portfolio/release_gate_dashboard"
        require_dependency "open_project/cityos_portfolio/calendar_export"
        require_dependency "open_project/cityos_portfolio/team_planner"
        require_dependency "open_project/cityos_portfolio/calculated_metrics"
        require_dependency "open_project/cityos_portfolio/pedd_integration"
      end

      # ── Register portfolio routes ───────────────────────
      initializer "cityos_portfolio.routes" do |app|
        app.routes.append do
          get "/cityos/portfolio", to: "cityos/portfolio/portfolio#index"
          get "/cityos/portfolio/systems", to: "cityos/portfolio/portfolio#systems"
          get "/cityos/portfolio/rollups", to: "cityos/portfolio/portfolio#rollups"
          get "/cityos/portfolio/system_graph", to: "cityos/portfolio/portfolio#system_graph"
          post "/cityos/portfolio/generate", to: "cityos/portfolio/portfolio#generate"
          get "/cityos/portfolio/calendar.ics", to: "cityos/portfolio/portfolio#calendar"
          get "/cityos/portfolio/team_planner", to: "cityos/portfolio/portfolio#team_planner"
          get "/cityos/portfolio/metrics", to: "cityos/portfolio/portfolio#metrics"
          get "/cityos/portfolio/pedd_entities", to: "cityos/portfolio/portfolio#pedd_entities"
          get "/cityos/portfolio/enriched_graph", to: "cityos/portfolio/portfolio#enriched_graph"
        end
      end
    end
  end
end
