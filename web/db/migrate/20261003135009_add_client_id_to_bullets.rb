# frozen_string_literal: true

class AddClientIdToBullets < ActiveRecord::Migration[8.1]
  def change
    add_column :bullets, :client_id, :string
    add_index :bullets, %i[user_id client_id], unique: true
  end
end
