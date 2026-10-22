class RemoveQueryFromSearchSelections < ActiveRecord::Migration[8.1]
  def change
    remove_column :search_selections, :query, :string
  end
end
