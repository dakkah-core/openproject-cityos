# frozen_string_literal: true

class CreateCityosStrategyPortfolios < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_portfolios do |t|
      t.string :name, null: false
      t.text :description
      t.references :owner, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.timestamps
    end
  end
end
