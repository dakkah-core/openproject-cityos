# frozen_string_literal: true

class CreateCityosStrategyDecisions < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_decisions do |t|
      t.string :title, null: false
      t.text :description
      t.text :options_considered
      t.string :selected_option
      t.text :rationale
      t.references :decision_owner, foreign_key: { to_table: :users }
      t.datetime :decided_at
      t.string :approval_ref
      t.integer :status, null: false, default: 0
      t.timestamps
    end
  end
end
