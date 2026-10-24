# frozen_string_literal: true

class CreateCollectionItems < ActiveRecord::Migration[8.1]
  def change
    create_table :collection_items do |t|
      t.references :collection, null: false, foreign_key: true
      t.references :bullet, null: false, foreign_key: true, index: { unique: true }
      t.integer :position, null: false
      t.timestamps
    end

    add_index :collection_items, %i[collection_id position]
  end
end
