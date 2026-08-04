module OpenProject
  module CityOSPortfolio
    class Engine < ::Rails::Engine
      engine_name 'openproject_cityos_portfolio'

      include OpenProject::Plugins::ActsAsOpEngine

      register(
        'openproject-cityos-portfolio',
        author_url: 'https://github.com/dakkah-core/openproject-cityos',
        requires_openproject: '>= 17.0.0'
      ) do
        project_module :cityos_portfolio do
          permission :view_cityos_portfolio,
                     { 'cityos/portfolio': [:index, :systems, :rollups, :system_graph] },
                     public: false
          permission :manage_cityos_portfolio,
                     { 'cityos/portfolio': [:generate] },
                     require: :loggedin
        end

        # ── Load all portfolio services ─────────────────────
        initializer 'cityos_portfolio.load_services' do
          require_dependency 'openproject-cityos-portfolio/hierarchy_generator'
          require_dependency 'openproject-cityos-portfolio/rollup_service'
          require_dependency 'openproject-cityos-portfolio/strategy_linker'
          require_dependency 'openproject-cityos-portfolio/dependency_view'
          require_dependency 'openproject-cityos-portfolio/stale_detector'
          require_dependency 'openproject-cityos-portfolio/release_gate_dashboard'
        end

        # ── Register portfolio routes ───────────────────────
        initializer 'cityos_portfolio.routes' do |app|
          app.routes.append do
            get '/cityos/portfolio', to: 'cityos/portfolio/portfolio#index'
            get '/cityos/portfolio/systems', to: 'cityos/portfolio/portfolio#systems'
            get '/cityos/portfolio/rollups', to: 'cityos/portfolio/portfolio#rollups'
            get '/cityos/portfolio/system_graph', to: 'cityos/portfolio/portfolio#system_graph'
            post '/cityos/portfolio/generate', to: 'cityos/portfolio/portfolio#generate'
          end
        end

        menu :top_menu,
             :cityos_portfolio,
             { controller: '/cityos/portfolio', action: :index },
             caption: 'CityOS Portfolio',
             icon: 'cityos-portfolio',
             after: :projects
      end
    end
  end
end
