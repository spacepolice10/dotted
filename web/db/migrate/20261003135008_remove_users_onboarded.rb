# frozen_string_literal: true

class RemoveUsersOnboarded < ActiveRecord::Migration[8.1]
  def up
    # Early databases omitted this column from CreateSchema.
    remove_column :users, :onboarded if column_exists?(:users, :onboarded)
  end

  def down
    add_column :users, :onboarded, :boolean, default: false, null: false unless column_exists?(:users, :onboarded)
  end
end
