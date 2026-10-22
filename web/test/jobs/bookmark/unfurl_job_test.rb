# frozen_string_literal: true

require 'test_helper'

class Bookmark::UnfurlJobTest < ActiveSupport::TestCase
  test 'updates a saved bookmark with fetched metadata' do
    bookmark = create_bullet!(users(:one), body: 'https://example.com').bookmarks.first
    unfurler = Struct.new(:metadata) { def call = metadata }.new({
      title: 'Example article', icon_link: 'https://example.com/favicon.ico',
      favicon: { io: StringIO.new('icon'), filename: 'favicon.ico', content_type: 'image/x-icon' }
    })

    job = Bookmark::UnfurlJob.new
    job.define_singleton_method(:unfurler_of) { |_url| unfurler }
    job.perform(bookmark)

    assert_equal 'Example article', bookmark.reload.title
    assert_equal 'https://example.com/favicon.ico', bookmark.icon_link
    assert bookmark.favicon.attached?
    assert bookmark.unfurled_at?
  end

  test 'fills in the favicon for an already unfurled bookmark' do
    bookmark = create_bullet!(users(:one), body: 'https://example.com').bookmarks.first
    bookmark.update!(title: 'Existing title', icon_link: 'https://example.com/favicon.ico', unfurled_at: Time.current)
    unfurler = Struct.new(:metadata) { def call = metadata }.new({
      title: 'Existing title', icon_link: 'https://example.com/favicon.ico',
      favicon: { io: StringIO.new('icon'), filename: 'favicon.ico', content_type: 'image/x-icon' }
    })

    job = Bookmark::UnfurlJob.new
    job.define_singleton_method(:unfurler_of) { |_link| unfurler }
    job.perform(bookmark)

    assert bookmark.reload.favicon.attached?
  end
end
