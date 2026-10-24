# frozen_string_literal: true

class RenameBulletDoneAtToCompletedAt < ActiveRecord::Migration[8.1]
  def change
    rename_column :bullets, :done_at, :completed_at
  end
end
