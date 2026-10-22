# frozen_string_literal: true

class AddFavoriteToCollections < ActiveRecord::Migration[8.1]
  def change
    add_column :collections, :favorite, :boolean, null: false, default: false
  end
end
