# frozen_string_literal: true

module OpenProject
  module CityOSStrategy
    class Engine < ::Rails::Engine
      engine_name "openproject_cityos_strategy"

      include OpenProject::Plugins::ActsAsOpEngine

      # Global Zeitwerk inflector for CityOS naming conventions.
      # Runs before any autoloader processes files.
      initializer "cityos_strategy.inflector", before: :set_autoload_paths do
        Zeitwerk::Loader.default_inflector = lambda do |camel, _abspath|
          {
            "cityos_strategy"     => "CityOSStrategy",
            "cityos_foundation"   => "CityOSFoundation",
            "cityos_governance"   => "CityOSGovernance",
            "cityos_identity"     => "CityOSIdentity",
            "cityos_portfolio"    => "CityOSPortfolio",
            "cityos"              => "CityOS",
            "sod_guard"           => "SoDGuard"
          }.fetch(camel) { Zeitwerk::Inflector::DEFAULT_INFLECTOR.call(camel, _abspath) }
        end
      end

      config.before_configuration do
        Rails.autoloaders.main.ignore(root.join("lib/openproject-cityos-strategy.rb"))
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
             icon: "icon-target",
             after: :overview

        menu :project_menu,
             :cityos_strategy_objectives,
             { controller: "/cityos/strategy/objectives", action: "index" },
             caption: :"cityos.strategy.label_objectives",
             parent: :cityos_strategy,
             icon: "icon-flag"

        menu :project_menu,
             :cityos_strategy_initiatives,
             { controller: "/cityos/strategy/initiatives", action: "index" },
             caption: :"cityos.strategy.label_initiatives",
             parent: :cityos_strategy,
             icon: "icon-rocket"

        menu :project_menu,
             :cityos_strategy_scenarios,
             { controller: "/cityos/strategy/scenarios", action: "index" },
             caption: :"cityos.strategy.label_scenarios",
             parent: :cityos_strategy,
             icon: "icon-branch"

        menu :project_menu,
             :cityos_strategy_metrics,
             { controller: "/cityos/strategy/metrics", action: "index" },
             caption: :"cityos.strategy.label_kpis",
             parent: :cityos_strategy,
             icon: "icon-meter"

        menu :project_menu,
             :cityos_strategy_reviews,
             { controller: "/cityos/strategy/reviews", action: "index" },
             caption: :"cityos.strategy.label_reviews",
             parent: :cityos_strategy,
             icon: "icon-checkmark"

        # ── Admin integration ────────────────────────────────────────
        menu :admin_menu,
             :cityos_strategy_admin,
             { controller: "/cityos/strategy/admin", action: "index" },
             caption: :"cityos.strategy.label_administration",
             icon: "icon-settings3",
             after: :cityos_foundation
      end

      # ── Locales ────────────────────────────────────────────────────
      initializer "cityos_strategy.register_locales" do |app|
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
