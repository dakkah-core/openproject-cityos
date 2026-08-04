# frozen_string_literal: true

class CreateCityosStrategyPrograms < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_programs do |t|
      t.string :name, null: false
      t.references :portfolio, null: false, foreign_key: { to_table: :cityos_strategy_portfolios }
      t.references :owner, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.timestamps
    end
  end
end
