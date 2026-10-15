# frozen_string_literal: true

require 'test_helper'
require_relative '../../db/migrate/20261015120000_rename_links_to_bookmarks'

class RenameLinksToBookmarksTest < ActiveSupport::TestCase
  test 'rewrites stored chip references reversibly without changing the records' do
    bullet = create_bullet!(users(:one), body: 'https://example.com')
    bookmark = bullet.bookmarks.first
    migration = RenameLinksToBookmarks.new

    migration.send(:rename_attachables, 'Bookmark', 'Link')
    fragment = Nokogiri::HTML.fragment(bullet.rich_text_body.reload.body.to_html)
    sgid = SignedGlobalID.parse(fragment.at_css('action-text-attachment')['sgid'], for: 'attachable')
    assert_equal 'Link', sgid.model_name
    assert_equal bookmark.id.to_s, sgid.model_id

    migration.send(:rename_attachables, 'Link', 'Bookmark')
    fragment = Nokogiri::HTML.fragment(bullet.rich_text_body.reload.body.to_html)
    assert_equal bookmark, Bookmark.from_attachable_sgid(fragment.at_css('action-text-attachment')['sgid'])
    assert_equal [bookmark.id], bullet.bookmarks.pluck(:id)
    assert_includes bullet.body.to_s, 'example.com'
  end
end
