# frozen_string_literal: true

class AddPostponementTrackingToBullets < ActiveRecord::Migration[8.1]
  def change
    add_column :bullets, :last_postponed_at, :datetime
    add_column :bullets, :postponements_number, :integer, null: false, default: 0
    add_index :bullets, :last_postponed_at
  end
end
