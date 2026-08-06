# frozen_string_literal: true

# HEXP-0801-0808: Executive Cockpit + Global-Cell + Arabic/RTL Data Models
# These are read-model projections for the Wave 8 UI.
# UI views read from these tables; business logic remains in Wave 1-7 services.
class CreateExecutiveCockpitAndUiModels < ActiveRecord::Migration[7.1]
  def change
    # ── HEXP-0801: Executive Strategy Dashboard ─────────────────────
    create_table :cityos_strategy_executive_dashboards do |t|
      t.string :stable_id, null: false
      t.references :plan, foreign_key: { to_table: :cityos_strategy_plans }
      t.jsonb :kpi_summary, default: {}
      t.jsonb :initiative_health, default: {}
      t.jsonb :coverage_gaps, default: []
      t.jsonb :risk_heatmap, default: {}
      t.jsonb :benefit_realization, default: {}
      t.datetime :refreshed_at
      t.string :refresh_source
      t.timestamps
    end

    add_index :cityos_strategy_executive_dashboards, :stable_id, unique: true

    # ── HEXP-0802: Global-Cell Views ────────────────────────────────
    create_table :cityos_strategy_global_cell_views do |t|
      t.string :stable_id, null: false
      t.string :country_cell, null: false
      t.references :plan, foreign_key: { to_table: :cityos_strategy_plans }
      t.jsonb :strategy_summary, default: {}
      t.jsonb :localization_overrides, default: {}
      t.string :locale, null: false, default: "en"
      t.boolean :rtl_enabled, null: false, default: false
      t.string :currency, default: "SAR"
      t.timestamps
    end

    add_index :cityos_strategy_global_cell_views, :stable_id, unique: true
    add_index :cityos_strategy_global_cell_views, :country_cell

    # ── HEXP-0803: Arabic/RTL Localization ──────────────────────────
    create_table :cityos_strategy_localizations do |t|
      t.string :stable_id, null: false
      t.string :localizable_type, null: false
      t.string :localizable_id, null: false
      t.string :locale, null: false, default: "ar"
      t.jsonb :translations, default: {}
      t.boolean :rtl_enabled, null: false, default: true
      t.string :status, null: false, default: "draft"
      t.timestamps
    end

    add_index :cityos_strategy_localizations, :stable_id, unique: true

    # ── HEXP-0804: Evidence Dashboard ───────────────────────────────
    create_table :cityos_strategy_evidence_dashboards do |t|
      t.string :stable_id, null: false
      t.references :plan, foreign_key: { to_table: :cityos_strategy_plans }
      t.jsonb :evidence_by_level, default: {}
      t.jsonb :gate_status, default: {}
      t.jsonb :freshness_summary, default: {}
      t.datetime :refreshed_at
      t.timestamps
    end

    add_index :cityos_strategy_evidence_dashboards, :stable_id, unique: true

    # ── HEXP-0805: Release Dashboard ────────────────────────────────
    create_table :cityos_strategy_release_dashboards do |t|
      t.string :stable_id, null: false
      t.references :plan, foreign_key: { to_table: :cityos_strategy_plans }
      t.string :current_candidate_id
      t.jsonb :gate_progress, default: {}
      t.jsonb :included_initiatives_summary, default: {}
      t.string :promotion_status
      t.datetime :refreshed_at
      t.timestamps
    end

    add_index :cityos_strategy_release_dashboards, :stable_id, unique: true

    # ── HEXP-0806: Coverage Dashboard ───────────────────────────────
    create_table :cityos_strategy_coverage_dashboards do |t|
      t.string :stable_id, null: false
      t.references :plan, foreign_key: { to_table: :cityos_strategy_plans }
      t.jsonb :semantic_coverage, default: {}
      t.jsonb :geographic_coverage, default: {}
      t.jsonb :service_coverage, default: {}
      t.jsonb :gap_analysis, default: {}
      t.datetime :refreshed_at
      t.timestamps
    end

    add_index :cityos_strategy_coverage_dashboards, :stable_id, unique: true

    # ── HEXP-0807: Engineering Service Status Dashboard ─────────────
    create_table :cityos_strategy_engineering_service_dashboards do |t|
      t.string :stable_id, null: false
      t.references :plan, foreign_key: { to_table: :cityos_strategy_plans }
      t.jsonb :service_statuses, default: {}
      t.jsonb :obligation_completion, default: {}
      t.jsonb :sla_adherence, default: {}
      t.datetime :refreshed_at
      t.timestamps
    end

    add_index :cityos_strategy_engineering_service_dashboards, :stable_id, unique: true

    # ── HEXP-0808: Accessibility Audit ──────────────────────────────
    create_table :cityos_strategy_accessibility_audits do |t|
      t.string :stable_id, null: false
      t.string :surface_type, null: false
      # enum: web, native, tv, kiosk, signage, car, watch
      t.string :wcag_level, null: false, default: "AA"
      t.jsonb :audit_results, default: {}
      t.jsonb :violations, default: []
      t.string :status, null: false, default: "pending"
      t.datetime :audited_at
      t.string :audited_by
      t.timestamps
    end

    add_index :cityos_strategy_accessibility_audits, :stable_id, unique: true
  end
end
