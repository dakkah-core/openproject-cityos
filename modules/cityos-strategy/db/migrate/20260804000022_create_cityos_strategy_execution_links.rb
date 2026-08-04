# frozen_string_literal: true

class CreateCityosStrategyExecutionLinks < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_execution_links do |t|
      t.references :strategic_initiative, null: false,
                   foreign_key: { to_table: :cityos_strategy_initiatives }
      t.references :work_package, null: false,
                   foreign_key: { to_table: :work_packages }
      t.decimal :contribution_weight, precision: 5, scale: 2, default: 1.0
      t.integer :link_type, null: false, default: 0
      t.timestamps
    end
    add_index :cityos_strategy_execution_links,
              %i[strategic_initiative_id work_package_id],
              unique: true, name: "idx_execution_links_uniq"
  end
end
