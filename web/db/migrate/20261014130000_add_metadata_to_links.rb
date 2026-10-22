# frozen_string_literal: true

class AddMetadataToLinks < ActiveRecord::Migration[8.1]
  def change
    add_column :links, :title, :string
    add_column :links, :image_url, :text
    add_column :links, :icon_url, :text
    add_column :links, :unfurled_at, :datetime
  end
end
