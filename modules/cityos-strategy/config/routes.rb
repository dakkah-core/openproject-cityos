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
    end
  end
end
