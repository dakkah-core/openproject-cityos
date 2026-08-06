# frozen_string_literal: true

class CreateCityosStrategyPlanAuthorizations < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_plan_authorizations do |t|
      t.string :authorization_id, null: false
      t.references :plan, foreign_key: { to_table: :cityos_strategy_plans }
      t.integer :plan_version, null: false
      t.string :plan_hash, null: false
      t.string :source_revision, null: false
      t.jsonb :approved_scope, null: false, default: {}
      t.string :dwos_approval_ref, null: false
      t.jsonb :dependency_snapshot, default: {}
      t.string :work_control_materialization_ref
      t.string :authorization_state, default: 'draft'
      t.references :authorized_by, foreign_key: { to_table: :users }
      t.datetime :authorized_at
      t.datetime :expires_at
      t.timestamps
    end

    add_index :cityos_strategy_plan_authorizations, :authorization_id, unique: true
    add_index :cityos_strategy_plan_authorizations, :authorization_state
    add_index :cityos_strategy_plan_authorizations, :dwos_approval_ref
  end
end
