# frozen_string_literal: true

class CreateChecklistItems < ActiveRecord::Migration[8.1]
  def change
    create_table :checklist_items do |t|
      t.references :checklist, null: false, foreign_key: true
      t.string :text, null: false
      t.integer :position, null: false, default: 0
      t.datetime :completed_at
      t.timestamps
    end

    add_index :checklist_items, %i[checklist_id position]
  end
end
