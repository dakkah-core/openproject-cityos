class CreateCityosScopeBindings < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_scope_bindings do |t|
      t.references :work_package, null: false, foreign_key: { to_table: :work_packages }, index: { unique: true }
      t.string :external_id, null: false
      t.string :scope_node_id
      t.string :work_item_id
      t.string :agent_task_id
      t.string :system_id
      t.string :capability_id
      t.string :journey_id
      t.string :experience_contract_id
      t.string :country_cell
      t.string :city_node
      t.string :tenant_scope
      t.string :source_repository
      t.string :source_revision, null: false
      t.string :source_hash
      t.timestamp :synced_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }

      t.timestamps
    end

    add_index :cityos_scope_bindings, :external_id
    add_index :cityos_scope_bindings, :system_id
    add_index :cityos_scope_bindings, :capability_id
  end
end
