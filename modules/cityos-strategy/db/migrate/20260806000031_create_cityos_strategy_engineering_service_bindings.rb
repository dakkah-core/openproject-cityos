# frozen_string_literal: true

class CreateCityosStrategyEngineeringServiceBindings < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_engineering_service_bindings do |t|
      t.string :binding_id, null: false
      t.references :objective, foreign_key: { to_table: :cityos_strategy_objectives }
      t.references :initiative, foreign_key: { to_table: :cityos_strategy_initiatives }
      t.string :service_id, null: false
      t.string :role, null: false, default: 'required'
      t.jsonb :input_obligations, default: {}
      t.jsonb :output_obligations, default: {}
      t.jsonb :entry_conditions, default: {}
      t.jsonb :exit_conditions, default: {}
      t.interval :target_sla, default: '7 days'
      t.string :gate_refs, array: true, default: []
      t.string :evidence_refs, array: true, default: []
      t.string :status, null: false, default: 'pending'
      t.timestamps
    end

    add_index :cityos_strategy_engineering_service_bindings, :binding_id, unique: true
    add_index :cityos_strategy_engineering_service_bindings, :service_id
    add_index :cityos_strategy_engineering_service_bindings, :status
    add_index :cityos_strategy_engineering_service_bindings,
              %i[objective_id service_id],
              unique: true, name: "idx_esb_obj_service_uniq"
    add_index :cityos_strategy_engineering_service_bindings,
              %i[initiative_id service_id],
              unique: true, name: "idx_esb_init_service_uniq"
  end
end
