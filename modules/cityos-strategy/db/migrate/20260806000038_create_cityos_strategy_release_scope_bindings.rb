# frozen_string_literal: true

# Wave 0 W0-4 (2026-08-07): add missing cityos_strategy_release_scope_bindings table.
#
# The `Cityos::Strategy::ReleaseScopeBinding` model
# (app/models/open_project/cityos_strategy/release_scope_binding.rb) exists
# and is referenced from downstream code, but no migration ever created
# its backing table. Any query against the model would raise
# ActiveRecord::StatementInvalid with "relation does not exist".
#
# Prior versions of this fix appeared to be missing from the migration
# directory entirely; earlier wave-0 recon reported the absence.
class CreateCityosStrategyReleaseScopeBindings < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_release_scope_bindings do |t|
      t.string :binding_id, null: false
      t.references :release_candidate, foreign_key: { to_table: :cityos_strategy_release_candidates }
      t.string :scope_type, null: false
      # enum: capability, initiative, plan, country_cell, jurisdiction
      t.string :scope_id, null: false
      t.string :compatibility_posture, null: false, default: "compatible"
      # enum: compatible, breaking-with-mitigation, breaking-blocker, unknown
      t.jsonb :evidence_refs, default: []
      t.string :source_revision
      t.datetime :evaluated_at
      t.string :evaluator_id
      t.timestamps
    end

    add_index :cityos_strategy_release_scope_bindings, :binding_id, unique: true
    add_index :cityos_strategy_release_scope_bindings, :scope_type
    add_index :cityos_strategy_release_scope_bindings,
              %i[release_candidate_id scope_type scope_id],
              unique: true,
              name: "idx_rsb_release_scope_unique"
  end
end
