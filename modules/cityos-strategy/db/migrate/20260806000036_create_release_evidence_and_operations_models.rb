# frozen_string_literal: true

# HEXP-0604-0608 + HEXP-0704-0706: Release, Evidence, Operations, Machine Identity
# Completes Wave 6 (3 remaining WPs) and Wave 7 (3 remaining WPs)
class CreateReleaseEvidenceAndOperationsModels < ActiveRecord::Migration[7.1]
  def change
    # ── HEXP-0604: Release Candidates ──────────────────────────────
    create_table :cityos_strategy_release_candidates do |t|
      t.string :stable_id, null: false
      t.references :plan, foreign_key: { to_table: :cityos_strategy_plans }
      t.string :version, null: false
      t.string :status, null: false, default: "draft"
      # enum: draft, staged, gated, approved, promoted, rolled-back
      t.jsonb :gate_results, default: {}
      t.jsonb :included_initiatives, default: []
      t.jsonb :benefits_summary, default: {}
      t.string :release_notes
      t.string :approved_by
      t.datetime :approved_at
      t.string :promotion_ref
      t.timestamps
    end

    add_index :cityos_strategy_release_candidates, :stable_id, unique: true

    # ── HEXP-0605: Evidence/UCL Projections ─────────────────────────
    create_table :cityos_strategy_evidence_projections do |t|
      t.string :stable_id, null: false
      t.references :initiative, foreign_key: { to_table: :cityos_strategy_initiatives }
      t.string :evidence_type, null: false
      # enum: design, source, test, integration, runtime, production
      t.string :status, null: false, default: "pending"
      t.jsonb :claims, default: []
      t.jsonb :acceptance_criteria, default: {}
      t.string :source_revision
      t.datetime :verified_at
      t.string :verified_by
      t.timestamps
    end

    add_index :cityos_strategy_evidence_projections, :stable_id, unique: true

    # ── HEXP-0606: Operations Runbook Bindings ──────────────────────
    create_table :cityos_strategy_operations_bindings do |t|
      t.string :stable_id, null: false
      t.references :plan, foreign_key: { to_table: :cityos_strategy_plans }
      t.string :runbook_ref
      t.string :slo_target
      t.string :incident_escalation
      t.string :backup_schedule
      t.string :restore_rto  # Recovery Time Objective
      t.string :restore_rpo  # Recovery Point Objective
      t.datetime :last_rehearsal_at
      t.string :rehearsal_status
      t.timestamps
    end

    add_index :cityos_strategy_operations_bindings, :stable_id, unique: true

    # ── HEXP-0607: Benefits Lifecycle ───────────────────────────────
    create_table :cityos_strategy_benefit_lifecycles do |t|
      t.string :stable_id, null: false
      t.references :benefit, foreign_key: { to_table: :cityos_strategy_benefits }
      t.string :stage, null: false, default: "projected"
      # enum: projected, baselined, measuring, realized, sustained, depreciated
      t.decimal :projected_value, precision: 15, scale: 2
      t.decimal :actual_value, precision: 15, scale: 2
      t.date :measured_at
      t.string :currency, default: "SAR"
      t.string :review_due_at
      t.timestamps
    end

    add_index :cityos_strategy_benefit_lifecycles, :stable_id, unique: true

    # ── HEXP-0704: Machine Identity Tokens ──────────────────────────
    create_table :cityos_strategy_machine_identities do |t|
      t.string :stable_id, null: false
      t.string :name, null: false
      t.string :token_hash, null: false
      t.string :scopes, array: true, default: []
      # e.g., ["strategy.read", "strategy.manage", "strategy.sync"]
      t.string :status, null: false, default: "active"
      t.datetime :expires_at
      t.datetime :last_used_at
      t.datetime :rotated_at
      t.string :created_by
      t.timestamps
    end

    add_index :cityos_strategy_machine_identities, :stable_id, unique: true
    add_index :cityos_strategy_machine_identities, :token_hash

    # ── HEXP-0705: Tenancy Audit Log ────────────────────────────────
    create_table :cityos_strategy_tenancy_audit_logs do |t|
      t.string :audit_id, null: false
      t.string :tenant_id, null: false
      t.string :actor_id
      t.string :action, null: false
      t.string :resource_type
      t.string :resource_id
      t.string :scope_node_id
      t.jsonb :before_state
      t.jsonb :after_state
      t.string :ip_address
      t.string :user_agent
      t.string :correlation_id
      t.timestamps
    end

    add_index :cityos_strategy_tenancy_audit_logs, :audit_id, unique: true
    add_index :cityos_strategy_tenancy_audit_logs, [:tenant_id, :created_at]
    add_index :cityos_strategy_tenancy_audit_logs, :actor_id

    # ── HEXP-0706: Key Rotation Schedule ────────────────────────────
    create_table :cityos_strategy_key_rotation_schedules do |t|
      t.string :stable_id, null: false
      t.string :key_type, null: false
      # enum: machine_token, api_key, signing_key, encryption_key
      t.string :key_identifier, null: false
      t.datetime :last_rotated_at
      t.datetime :next_rotation_due
      t.integer :rotation_interval_days, null: false, default: 90
      t.string :status, null: false, default: "active"
      t.string :rotated_by
      t.timestamps
    end

    add_index :cityos_strategy_key_rotation_schedules, :stable_id, unique: true
    add_index :cityos_strategy_key_rotation_schedules,
              [:key_type, :key_identifier],
              unique: true,
              name: "idx_key_rotation_type_identifier"
  end
end
