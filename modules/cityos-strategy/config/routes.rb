# frozen_string_literal: true

OpenProject::CityosStrategy::Engine.routes.draw do
  # ── Dashboard ─────────────────────────────────────────────────────
  get "dashboard", to: "dashboard#show", as: :strategy_dashboard

  # ── Strategic Plans ───────────────────────────────────────────────
  resources :plans, controller: "strategic_plans" do
    member do
      post :baseline
    end
  end

  # ── Objectives & Key Results ──────────────────────────────────────
  resources :objectives do
    member do
      post :score
    end
    resources :key_results, only: %i[new create edit update destroy]
  end

  # ── Initiatives ───────────────────────────────────────────────────
  resources :initiatives do
    member do
      post :score
      post :advance_stage
    end
    resources :benefits, only: %i[new create edit update destroy]
  end

  # ── Scenarios ─────────────────────────────────────────────────────
  resources :scenarios do
    member do
      post :freeze
      post :unfreeze
    end
    resources :allocations, only: %i[new create edit update destroy]
  end

  # ── KPI Metrics ───────────────────────────────────────────────────
  resources :metrics do
    resources :metric_observations, only: %i[new create edit update destroy],
              as: :observations
  end

  # ── Strategic Reviews ─────────────────────────────────────────────
  resources :reviews do
    member do
      post :snapshot
    end
  end

  # ── Benefits ──────────────────────────────────────────────────────
  resources :benefits, only: %i[index show edit update]

  # ── Risks & Assumptions ───────────────────────────────────────────
  resources :risks
  resources :assumptions, only: %i[index show edit update destroy]

  # ── Cross-System Dependencies ─────────────────────────────────────
  resources :dependencies, only: %i[index show new create edit update destroy]

  # ── Resource Allocations ──────────────────────────────────────────
  resources :allocations, only: %i[index show]

  # ── Strategic Decisions ───────────────────────────────────────────
  resources :decisions

  # ── REST API (for MCP + sync service) ─────────────────────────────
  namespace :api do
    scope module: :v1, path: "v1" do
      get  "objectives",    to: "objectives#index"
      get  "objectives/:id", to: "objectives#show"

      get  "initiatives",    to: "initiatives#index"
      get  "initiatives/:id", to: "initiatives#show"
      post "initiatives/:id/score", to: "initiatives#score"

      get  "scenarios",    to: "scenarios#index"
      get  "scenarios/:id", to: "scenarios#show"

      get  "metrics",             to: "metrics#index"
      get  "metrics/:id",         to: "metrics#show"
      post "metrics/:id/observe", to: "metrics#record_observation"

      get  "reviews",    to: "reviews#index"
      get  "reviews/:id", to: "reviews#show"

      get  "benefits",    to: "benefits#index"
      get  "benefits/:id", to: "benefits#show"

      get  "dependencies",    to: "dependencies#index"
      get  "dependencies/:id", to: "dependencies#show"

      get  "allocations",    to: "allocations#index"
      get  "allocations/:id", to: "allocations#show"

      # Wave 1 W1-7 (2026-08-07): the block below was orphaned at file scope
      # after the Engine.routes.draw do…end block closed — Rails would raise
      # NoMethodError on load if the file were fully evaluated. Moved inside
      # the api/v1 scope where the routes were intended.

      # Engineering Service Bindings
      get   "engineering_service_bindings",            to: "engineering_service_bindings#index"
      get   "engineering_service_bindings/coverage",   to: "engineering_service_bindings#coverage"
      post  "engineering_service_bindings",            to: "engineering_service_bindings#create"
      post  "engineering_service_bindings/create_defaults", to: "engineering_service_bindings#create_defaults"
      get   "engineering_service_bindings/:id",        to: "engineering_service_bindings#show"
      patch "engineering_service_bindings/:id",        to: "engineering_service_bindings#update"

      # Coverage Baselines & Targets
      get   "coverage/baselines",                      to: "coverage#baselines"
      post  "coverage/baselines",                      to: "coverage#create_baseline"
      get   "coverage/baselines/:id/compare",          to: "coverage#compare_baselines"
      get   "coverage/baselines/:id/gaps",             to: "coverage#gaps"
      get   "coverage/targets",                        to: "coverage#targets"
      post  "coverage/targets",                        to: "coverage#create_target"

      # Plan Authorizations
      get   "plan_authorizations",                     to: "plan_authorizations#index"
      post  "plan_authorizations",                     to: "plan_authorizations#create"
      get   "plan_authorizations/:id",                 to: "plan_authorizations#show"
      patch "plan_authorizations/:id",                 to: "plan_authorizations#update"
    end
  end
end
