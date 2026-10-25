# frozen_string_literal: true

class AddReviewedAtToBullets < ActiveRecord::Migration[8.1]
  def change
    add_column :bullets, :reviewed_at, :datetime
    add_index :bullets, :reviewed_at
  end
end
