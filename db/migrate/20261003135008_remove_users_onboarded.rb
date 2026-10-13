# frozen_string_literal: true

class RemoveUsersOnboarded < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :onboarded, :boolean, default: false, null: false
  end
end
