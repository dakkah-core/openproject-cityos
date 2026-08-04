# frozen_string_literal: true

class CreateCityosStrategyDependencies < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_dependencies do |t|
      t.references :from_initiative, null: false, foreign_key: { to_table: :cityos_strategy_initiatives }
      t.references :to_initiative, null: false, foreign_key: { to_table: :cityos_strategy_initiatives }
      t.integer :dependency_type, null: false, default: 0
      t.boolean :critical_path, default: false
      t.integer :status, null: false, default: 0
      t.timestamps
    end
  end
end
