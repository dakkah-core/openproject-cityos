# frozen_string_literal: true

class CreateCityosStrategyGlobalizationBindings < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_globalization_bindings do |t|
      t.string :binding_id, null: false
      t.references :objective, foreign_key: { to_table: :cityos_strategy_objectives }
      t.references :initiative, foreign_key: { to_table: :cityos_strategy_initiatives }
      t.string :country_cell, null: false
      t.string :jurisdiction
      t.string :language, default: 'ar'
      t.string :currency, default: 'SAR'
      t.string :residency_zone
      t.string :cultural_profile
      t.string :accessibility_profile
      t.string :fiscal_profile
      t.string :identity_federation
      t.date :applicable_from
      t.timestamps
    end

    add_index :cityos_strategy_globalization_bindings, :binding_id, unique: true
    add_index :cityos_strategy_globalization_bindings, :country_cell

    create_table :cityos_strategy_core_contribution_profiles do |t|
      t.string :profile_id, null: false
      t.string :scope_node_id, null: false
      t.string :cms_contribution, default: 'not-applicable'
      t.string :agora_contribution, default: 'not-applicable'
      t.string :nexus_contribution, default: 'not-applicable'
      t.string :tryton_contribution, default: 'not-applicable'
      t.jsonb :shared_systems, default: {}
      t.text :notes
      t.timestamps
    end

    add_index :cityos_strategy_core_contribution_profiles, :profile_id, unique: true
    add_index :cityos_strategy_core_contribution_profiles, :scope_node_id
  end
end
