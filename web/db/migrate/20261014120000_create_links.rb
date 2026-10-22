# frozen_string_literal: true

class CreateLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :links do |t|
      t.references :bullet, null: false, foreign_key: true
      t.text :url, null: false

      t.timestamps
    end

    add_index :links, %i[bullet_id url], unique: true
  end
end
