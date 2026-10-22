# frozen_string_literal: true

class RenameBookmarkUrlToLink < ActiveRecord::Migration[8.1]
  def change
    rename_column :bookmarks, :url, :link
  end
end
