# frozen_string_literal: true

class RenameBookmarkIconUrlToIconLink < ActiveRecord::Migration[8.1]
  def change
    rename_column :bookmarks, :icon_url, :icon_link
  end
end
