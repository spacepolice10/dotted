# frozen_string_literal: true

require 'test_helper'

class BookmarkTest < ActiveSupport::TestCase
  setup do
    @bullet = create_bullet!(users(:one), body: 'Read later')
  end

  test 'stores an HTTP URL after trimming surrounding whitespace' do
    bookmark = @bullet.bookmarks.create!(link: ' https://example.com/article?part=1 ')

    assert_equal 'https://example.com/article?part=1', bookmark.reload.link
  end

  test 'rejects non-web and malformed URLs' do
    ['mailto:a@example.com', 'javascript:alert(1)', 'not a URL', 'https://', 'https://user:pass@example.com'].each do |url|
      bookmark = @bullet.bookmarks.new(link: url)

      assert_not bookmark.valid?, url
      assert_includes bookmark.errors[:link], 'must be an HTTP or HTTPS URL'
    end
  end

  test 'allows one record per URL per bullet' do
    @bullet.bookmarks.create!(link: 'https://example.com')

    duplicate = @bullet.bookmarks.new(link: ' https://example.com ')
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:link], 'has already been taken'

    other_bullet = create_bullet!(users(:one), body: 'Another note')
    assert other_bullet.bookmarks.create!(link: 'https://example.com').persisted?
  end

  test 'removing the bullet removes its bookmarks' do
    @bullet.bookmarks.create!(link: 'https://example.com')

    assert_difference 'Bookmark.count', -1 do
      @bullet.destroy!
    end
  end
end
