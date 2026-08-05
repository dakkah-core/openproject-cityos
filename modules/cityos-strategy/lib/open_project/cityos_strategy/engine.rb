# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class Engine < ::Rails::Engine
      engine_name "openproject_cityos_strategy"

      include OpenProject::Plugins::ActsAsOpEngine

      config.before_configuration do
        Rails.autoloaders.main.ignore(root.join("lib/openproject-cityos-strategy.rb"))
        # Multi-model files (Zeitwerk expects 1:1 file:constant)
        %w[governance initiatives metrics objectives adapters ai_services].each do |f|
          Rails.autoloaders.main.ignore(root.join("app/models/open_project/cityos_strategy/#{f}.rb"))
          Rails.autoloaders.main.ignore(root.join("app/services/open_project/cityos_strategy/#{f}.rb"))
        end
      end

      register(
        "openproject-cityos-strategy",
        author_url: "https://github.com/dakkah-core/cityos-helm",
        requires_openproject: ">= 17.6.0"
      ) do
        # ── Permissions ──────────────────────────────────────────────
        project_module :cityos_strategy do
          # Dashboard
          permission :view_strategy_dashboard,
                     { "cityos/strategy/dashboard": [:show] },
                     permissible_on: [:project],
                     public: true

          # Strategic Plans
          permission :view_strategic_plans,
                     { "cityos/strategy/plans": %i[index show] },
                     permissible_on: [:project],
                     public: true
          permission :manage_strategic_plans,
                     { "cityos/strategy/plans": %i[new create edit update destroy baseline] },
                     permissible_on: [:project],
                     require: :loggedin

          # Objectives & Key Results
          permission :view_objectives,
                     { "cityos/strategy/objectives": %i[index show] },
                     permissible_on: [:project],
                     public: true
          permission :manage_objectives,
                     { "cityos/strategy/objectives": %i[new create edit update destroy score] },
                     permissible_on: [:project],
                     require: :loggedin

          # Initiatives
          permission :view_initiatives,
                     { "cityos/strategy/initiatives": %i[index show] },
                     permissible_on: [:project],
                     public: true
          permission :manage_initiatives,
                     { "cityos/strategy/initiatives": %i[new create edit update destroy score advance_stage] },
                     permissible_on: [:project],
                     require: :loggedin

          # Scenarios
          permission :view_scenarios,
                     { "cityos/strategy/scenarios": %i[index show] },
                     permissible_on: [:project],
                     public: true
          permission :manage_scenarios,
                     { "cityos/strategy/scenarios": %i[new create edit update destroy freeze unfreeze] },
                     permissible_on: [:project],
                     require: :loggedin

          # KPI Metrics
          permission :view_metrics,
                     { "cityos/strategy/metrics": %i[index show] },
                     permissible_on: [:project],
                     public: true
          permission :manage_metrics,
                     { "cityos/strategy/metrics": %i[new create edit update destroy record_observation] },
                     permissible_on: [:project],
                     require: :loggedin

          # Reviews
          permission :view_reviews,
                     { "cityos/strategy/reviews": %i[index show] },
                     permissible_on: [:project],
                     public: true
          permission :manage_reviews,
                     { "cityos/strategy/reviews": %i[new create edit update destroy snapshot] },
                     permissible_on: [:project],
                     require: :loggedin

          # Benefits
          permission :view_benefits,
                     { "cityos/strategy/benefits": %i[index show] },
                     permissible_on: [:project],
                     public: true
          permission :manage_benefits,
                     { "cityos/strategy/benefits": %i[new create edit update destroy] },
                     permissible_on: [:project],
                     require: :loggedin

          # Risks
          permission :view_risks,
                     { "cityos/strategy/risks": %i[index show] },
                     permissible_on: [:project],
                     public: true
          permission :manage_risks,
                     { "cityos/strategy/risks": %i[new create edit update destroy] },
                     permissible_on: [:project],
                     require: :loggedin

          # Dependencies
          permission :view_dependencies,
                     { "cityos/strategy/dependencies": %i[index show] },
                     permissible_on: [:project],
                     public: true
          permission :manage_dependencies,
                     { "cityos/strategy/dependencies": %i[new create edit update destroy] },
                     permissible_on: [:project],
                     require: :loggedin

          # Allocations
          permission :view_allocations,
                     { "cityos/strategy/allocations": %i[index show] },
                     permissible_on: [:project],
                     public: true
          permission :manage_allocations,
                     { "cityos/strategy/allocations": %i[new create edit update destroy] },
                     permissible_on: [:project],
                     require: :loggedin

          # Decisions
          permission :view_decisions,
                     { "cityos/strategy/decisions": %i[index show] },
                     permissible_on: [:project],
                     public: true
          permission :manage_decisions,
                     { "cityos/strategy/decisions": %i[new create edit update destroy] },
                     permissible_on: [:project],
                     require: :loggedin

          # API — for MCP and sync service access
          permission :access_strategy_api,
                     { "cityos/strategy/api": %i[objectives initiatives scenarios metrics reviews benefits dependencies allocations] },
                     permissible_on: [:project],
                     public: false
        end

        # ── Menus ────────────────────────────────────────────────────
        menu :project_menu,
             :cityos_strategy,
             { controller: "/cityos/strategy/dashboard", action: "show" },
             caption: :"cityos.strategy.label_strategy",
             after: :overview

        menu :project_menu,
             :cityos_strategy_objectives,
             { controller: "/cityos/strategy/objectives", action: "index" },
             caption: :"cityos.strategy.label_objectives",
             parent: :cityos_strategy

        menu :project_menu,
             :cityos_strategy_initiatives,
             { controller: "/cityos/strategy/initiatives", action: "index" },
             caption: :"cityos.strategy.label_initiatives",
             parent: :cityos_strategy

        menu :project_menu,
             :cityos_strategy_scenarios,
             { controller: "/cityos/strategy/scenarios", action: "index" },
             caption: :"cityos.strategy.label_scenarios",
             parent: :cityos_strategy

        menu :project_menu,
             :cityos_strategy_metrics,
             { controller: "/cityos/strategy/metrics", action: "index" },
             caption: :"cityos.strategy.label_kpis",
             parent: :cityos_strategy

        menu :project_menu,
             :cityos_strategy_reviews,
             { controller: "/cityos/strategy/reviews", action: "index" },
             caption: :"cityos.strategy.label_reviews",
             parent: :cityos_strategy

        # ── Admin integration ────────────────────────────────────────
        menu :admin_menu,
             :cityos_strategy_admin,
             { controller: "/cityos/strategy/admin", action: "index" },
             caption: :"cityos.strategy.label_administration",
             after: :cityos_foundation
      end

        # ── Routes ────────────────────────────────────────────────────
      initializer "cityos_strategy.routes" do |app|
        app.routes.append do
          get "/cityos/strategy/admin",
              to: "cityos/strategy/admin#index"

          # Dashboard
          get "/projects/:project_id/cityos/strategy/dashboard(/:action)",
              to: "cityos/strategy/dashboard#show",
              as: :cityos_strategy_dashboard

          scope "/projects/:project_id" do
            # Strategic Plans
            resources :cityos_strategy_plans,
                      controller: "cityos/strategy/plans",
                      path: "cityos/strategy/plans",
                      only: %i[index show new create edit update destroy] do
              member { post :baseline }
            end

            # Objectives
            resources :cityos_strategy_objectives,
                      controller: "cityos/strategy/objectives",
                      path: "cityos/strategy/objectives",
                      only: %i[index show new create edit update destroy] do
              member { post :score }
            end

            # Initiatives
            resources :cityos_strategy_initiatives,
                      controller: "cityos/strategy/initiatives",
                      path: "cityos/strategy/initiatives",
                      only: %i[index show new create edit update destroy] do
              member { post :score; post :advance_stage }
            end

            # Scenarios
            resources :cityos_strategy_scenarios,
                      controller: "cityos/strategy/scenarios",
                      path: "cityos/strategy/scenarios",
                      only: %i[index show new create edit update destroy] do
              member { post :freeze; post :unfreeze }
            end

            # Metrics
            resources :cityos_strategy_metrics,
                      controller: "cityos/strategy/metrics",
                      path: "cityos/strategy/metrics",
                      only: %i[index show new create edit update destroy] do
              member { post :record_observation }
            end

            # Reviews
            resources :cityos_strategy_reviews,
                      controller: "cityos/strategy/reviews",
                      path: "cityos/strategy/reviews",
                      only: %i[index show new create edit update destroy] do
              member { post :snapshot }
            end

            # Benefits
            resources :cityos_strategy_benefits,
                      controller: "cityos/strategy/benefits",
                      path: "cityos/strategy/benefits",
                      only: %i[index show new create edit update destroy]

            # Allocations
            resources :cityos_strategy_allocations,
                      controller: "cityos/strategy/allocations",
                      path: "cityos/strategy/allocations",
                      only: %i[index show new create edit update destroy]

            # Dependencies
            resources :cityos_strategy_dependencies,
                      controller: "cityos/strategy/dependencies",
                      path: "cityos/strategy/dependencies",
                      only: %i[index show new create edit update destroy]

            # Risks
            resources :cityos_strategy_risks,
                      controller: "cityos/strategy/risks",
                      path: "cityos/strategy/risks",
                      only: %i[index show new create edit update destroy]

            # Decisions
            resources :cityos_strategy_decisions,
                      controller: "cityos/strategy/decisions",
                      path: "cityos/strategy/decisions",
                      only: %i[index show new create edit update destroy]
          end

          # API (global, not project-scoped)
          namespace :cityos do
            namespace :strategy do
              namespace :api do
                namespace :v1 do
                  resources :objectives, only: %i[index show]
                  resources :initiatives, only: %i[index show]
                  resources :metrics, only: %i[index show]
                end
              end
            end
          end

        end
      end

      # ── Locales ────────────────────────────────────────────────────
      initializer "cityos_strategy.register_locales" do |app|
        # Load multi-model files (ignored by Zeitwerk because each
        # defines 3+ constants — Zeitwerk expects 1:1 file:constant).
        require_dependency "open_project/cityos_strategy/strategic_plan"
        require_dependency "open_project/cityos_strategy/objectives"
        require_dependency "open_project/cityos_strategy/initiatives"
        require_dependency "open_project/cityos_strategy/governance"
        require_dependency "open_project/cityos_strategy/metrics"
        require_dependency "open_project/cityos_strategy/adapters"
        require_dependency "open_project/cityos_strategy/ai_services"
        require_dependency "open_project/cityos_strategy/health_service"
        require_dependency "open_project/cityos_strategy/scenario_service"
        require_dependency "open_project/cityos_strategy/scoring_service"
        require_dependency "open_project/cityos_strategy/snapshot_service"

        app.config.i18n.load_path += Dir[
          File.join(File.dirname(__FILE__), "..", "..", "config", "locales", "*.yml")
        ]
      end

      # ── Assets ─────────────────────────────────────────────────────
      initializer "cityos_strategy.assets" do |app|
        app.config.assets.precompile += %w[
          cityos-strategy.css
          cityos-strategy.js
        ]
      end

      # ── API routes ─────────────────────────────────────────────────
      initializer "cityos_strategy.api_routes" do |app|
        app.config.after_initialize do
          # API routes are mounted at /api/cityos/v1/strategy/
          # See config/routes.rb in the strategy module
        end
      end
    end
  end
end
