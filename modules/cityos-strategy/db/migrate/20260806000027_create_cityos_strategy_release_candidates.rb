# frozen_string_literal: true

class CreateCityosStrategyReleaseCandidates < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_release_candidates do |t|
      t.string :candidate_id, null: false
      t.string :version, null: false
      t.string :source_revision, null: false
      t.string :included_capabilities, array: true, default: []
      t.string :included_initiatives, array: true, default: []
      t.string :activation_set_target
      t.jsonb :proof_policy, default: {}
      t.string :rollback_target
      t.string :lifecycle_state, default: 'draft'
      t.string :ucl_evaluation_ref
      t.timestamps
    end

    add_index :cityos_strategy_release_candidates, :candidate_id, unique: true
    add_index :cityos_strategy_release_candidates, :lifecycle_state

    create_table :cityos_strategy_release_scope_bindings do |t|
      t.string :binding_id, null: false
      t.string :candidate_id
      t.string :scope_type, null: false
      t.string :scope_id, null: false
      t.string :inclusion_reason
      t.string :compatibility_posture, default: 'compatible'
      t.timestamps
    end

    add_index :cityos_strategy_release_scope_bindings, :binding_id, unique: true
    add_index :cityos_strategy_release_scope_bindings, :candidate_id
    add_index :cityos_strategy_release_scope_bindings, %i[candidate_id scope_id], unique: true, name: "idx_release_scope_uniq"
  end
end
