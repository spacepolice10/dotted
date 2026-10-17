# frozen_string_literal: true

class CreateNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :notes do |t|
      t.references :notable, polymorphic: true, null: false, index: { unique: true }
      t.timestamps
    end
  end
end
