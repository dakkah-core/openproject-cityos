# frozen_string_literal: true

# HEXP-0401-0407: Universal Strategy Model
# Semantic scope bindings, engineering service obligations,
# coverage baselines, and 4-core contribution profiles.
class CreateUniversalStrategyModels < ActiveRecord::Migration[7.1]
  def change
    # ── HEXP-0401: Universal Plan Hierarchy ─────────────────────────
    create_table :cityos_strategy_plan_hierarchy do |t|
      t.string :stable_id, null: false
      t.references :strategic_plan, foreign_key: { to_table: :cityos_strategy_plans }
      t.string :scope_type, null: false
      # enum: global, country_cell, zone, jurisdiction, vertical, subvertical
      t.string :scope_value, null: false
      t.references :parent, foreign_key: { to_table: :cityos_strategy_plan_hierarchy }
      t.integer :depth, null: false, default: 0
      t.string :coverage_target
      t.string :coverage_baseline
      t.string :status, null: false, default: "draft"
      t.timestamps
    end

    add_index :cityos_strategy_plan_hierarchy, :stable_id, unique: true

    # ── HEXP-0402: Semantic Scope Bindings ───────────────────────────
    create_table :cityos_strategy_semantic_scope_bindings do |t|
      t.string :stable_id, null: false
      t.string :bindable_type, null: false  # StrategicPlan, StrategicInitiative, etc.
      t.string :bindable_id, null: false
      t.string :semantic_domain, null: false
      # enum: life, business, profession, community, governance, infrastructure
      t.string :semantic_subdomain
      t.string :coverage_class, null: false
      # enum: current, target, transition, gap, not-applicable
      t.jsonb :attributes, default: {}
      t.string :status, null: false, default: "draft"
      t.timestamps
    end

    add_index :cityos_strategy_semantic_scope_bindings, :stable_id, unique: true
    add_index :cityos_strategy_semantic_scope_bindings,
              [:bindable_type, :bindable_id],
              name: "idx_semantic_scope_bindable"

    # ── HEXP-0403: Coverage Baselines/Targets ────────────────────────
    create_table :cityos_strategy_coverage_baselines do |t|
      t.string :stable_id, null: false
      t.references :plan, foreign_key: { to_table: :cityos_strategy_plans }
      t.string :dimension, null: false
      # enum: semantic, geographic, demographic, service, capability
      t.decimal :current_value, precision: 8, scale: 4
      t.decimal :target_value, precision: 8, scale: 4
      t.decimal :transition_gap, precision: 8, scale: 4
      t.string :unit
      t.date :measured_at
      t.date :target_date
      t.string :status, null: false, default: "draft"
      t.timestamps
    end

    add_index :cityos_strategy_coverage_baselines, :stable_id, unique: true

    # ── HEXP-0404: Four-Core Contribution Profiles ───────────────────
    create_table :cityos_strategy_contribution_profiles do |t|
      t.string :stable_id, null: false
      t.references :initiative, foreign_key: { to_table: :cityos_strategy_initiatives }
      t.string :profile_type, null: false
      # enum: life_quality, business_enablement, profession_advancement, platform_sustainability
      t.decimal :contribution_weight, precision: 5, scale: 4, null: false, default: 0.25
      t.text :evidence_summary
      t.jsonb :metrics, default: {}
      t.string :status, null: false, default: "draft"
      t.timestamps
    end

    add_index :cityos_strategy_contribution_profiles, :stable_id, unique: true

    # ── HEXP-0405: Globalization Bindings ────────────────────────────
    create_table :cityos_strategy_globalization_bindings do |t|
      t.string :stable_id, null: false
      t.references :plan, foreign_key: { to_table: :cityos_strategy_plans }
      t.string :country_cell, null: false
      t.string :locale, null: false, default: "en"
      t.string :currency, null: false, default: "SAR"
      t.string :timezone, null: false, default: "Asia/Riyadh"
      t.string :calendar_type, null: false, default: "gregorian"
      # also: hijri
      t.boolean :rtl_enabled, null: false, default: false
      t.jsonb :localization_overrides, default: {}
      t.string :status, null: false, default: "draft"
      t.timestamps
    end

    add_index :cityos_strategy_globalization_bindings, :stable_id, unique: true

    # ── Wave 3 (06): Engineering Service Obligation Bindings ─────────
    create_table :cityos_strategy_engineering_service_bindings do |t|
      t.string :stable_id, null: false
      t.string :bindable_type, null: false
      t.string :bindable_id, null: false
      t.string :engineering_service_id, null: false
      # One of: helm, docs, pedd, psee, dwos, ucl, work_control,
      #         extension_fabric, assurance, operations, semantic_universe,
      #         compiler, connectors, universal_tool, maestro, ai_gateway,
      #         data_analytics
      t.string :role, null: false, default: "required"
      # enum: required, supporting, observer, not_applicable
      t.jsonb :required_inputs, default: {}
      t.jsonb :required_outputs, default: {}
      t.jsonb :entry_conditions, default: {}
      t.jsonb :exit_conditions, default: {}
      t.string :target_sla
      t.string :status, null: false, default: "pending"
      t.string :source_revision
      t.jsonb :evidence_refs, default: []
      t.datetime :last_observed_at
      t.string :freshness_state, default: "stale"
      t.timestamps
    end

    add_index :cityos_strategy_engineering_service_bindings, :stable_id, unique: true
    add_index :cityos_strategy_engineering_service_bindings,
              [:bindable_type, :bindable_id, :engineering_service_id],
              unique: true,
              name: "idx_eng_svc_binding_unique"
  end
end
