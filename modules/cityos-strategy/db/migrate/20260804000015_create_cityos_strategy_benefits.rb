# frozen_string_literal: true

class CreateCityosStrategyBenefits < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_benefits do |t|
      t.references :initiative, null: false, foreign_key: { to_table: :cityos_strategy_initiatives }
      t.integer :benefit_type, null: false, default: 0
      t.text :description
      t.decimal :baseline, precision: 15, scale: 4
      t.decimal :target, precision: 15, scale: 4, null: false
      t.decimal :current_value, precision: 15, scale: 4
      t.date :realization_date
      t.text :measurement_method
      t.integer :sustainability_period
      t.integer :status, null: false, default: 0
      t.references :benefit_owner, foreign_key: { to_table: :users }
      t.string :beneficiary
      t.timestamps
    end
  end
end
