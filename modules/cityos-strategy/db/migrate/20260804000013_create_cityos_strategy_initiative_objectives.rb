# frozen_string_literal: true

class CreateCityosStrategyInitiativeObjectives < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_initiative_objectives do |t|
      t.references :initiative, null: false, foreign_key: { to_table: :cityos_strategy_initiatives }
      t.references :objective, null: false, foreign_key: { to_table: :cityos_strategy_objectives }
      t.decimal :contribution_weight, precision: 5, scale: 2, default: 1.0
      t.timestamps
    end
    add_index :cityos_strategy_initiative_objectives,
              %i[initiative_id objective_id], unique: true,
              name: "idx_initiative_objectives_uniq"
  end
end
