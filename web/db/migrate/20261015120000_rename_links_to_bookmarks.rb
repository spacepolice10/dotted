# frozen_string_literal: true

class RenameLinksToBookmarks < ActiveRecord::Migration[8.1]
  def up
    rename_table :links, :bookmarks
    rename_attachables 'Link', 'Bookmark'
  end

  def down
    rename_attachables 'Bookmark', 'Link'
    rename_table :bookmarks, :links
  end

  private

  def rename_attachables(from, to)
    ActionText::RichText.where('body LIKE ?', '%application/vnd.dotted.link-chip%').find_each do |rich_text|
      fragment = Nokogiri::HTML.fragment(rich_text.body.to_html)
      fragment.css('action-text-attachment').each do |node|
        sgid = SignedGlobalID.parse(node['sgid'], for: 'attachable')
        next unless sgid&.model_name == from

        node['sgid'] = SignedGlobalID.new("gid://#{sgid.app}/#{to}/#{sgid.model_id}",
          for: 'attachable', expires_in: nil).to_s
      end

      rich_text.update_columns(body: fragment.to_html) if fragment.to_html != rich_text.body.to_html
    end
  end
end
