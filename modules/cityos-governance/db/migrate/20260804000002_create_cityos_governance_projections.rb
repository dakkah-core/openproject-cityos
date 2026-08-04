class CreateCityosGovernanceProjections < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_governance_projections do |t|
      t.references :work_package, null: false, foreign_key: { to_table: :work_packages }, index: { unique: true }
      t.string :ucl_status, null: false
      t.string :design_maturity
      t.string :runtime_maturity
      t.string :product_maturity
      t.string :proof_status
      t.string :target_runtime_proof_status
      t.string :approval_ref
      t.string :approval_state
      t.string :owner_lane
      t.string :gate_id
      t.boolean :release_claim_allowed, default: false
      t.string :source_revision, null: false
      t.string :projection_hash, null: false
      t.timestamp :projected_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }

      t.timestamps
    end

    add_index :cityos_governance_projections, :ucl_status
    add_index :cityos_governance_projections, :gate_id
    add_index :cityos_governance_projections, :owner_lane
    add_index :cityos_governance_projections, :approval_state
  end
end
