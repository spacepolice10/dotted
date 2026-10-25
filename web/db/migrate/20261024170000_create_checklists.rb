# frozen_string_literal: true

class CreateChecklists < ActiveRecord::Migration[8.1]
  def change
    create_table :checklists do |t|
      t.references :bullet, null: false, foreign_key: true, index: { unique: true }
      t.timestamps
    end
  end
end
