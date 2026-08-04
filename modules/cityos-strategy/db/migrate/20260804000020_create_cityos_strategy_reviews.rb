# frozen_string_literal: true

class CreateCityosStrategyReviews < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_strategy_reviews do |t|
      t.integer :review_type, null: false, default: 0
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.integer :status, null: false, default: 0
      t.references :facilitator, foreign_key: { to_table: :users }
      t.timestamps
    end
  end
end
