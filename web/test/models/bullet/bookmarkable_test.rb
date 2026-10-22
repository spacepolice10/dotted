# frozen_string_literal: true

require 'test_helper'

class Bullet::BookmarkableTest < ActiveSupport::TestCase
  test 'indexes URLs in saved text and removes them after an edit' do
    bullet = create_bullet!(users(:one), body: 'Read https://example.com/article.')

    assert_equal ['https://example.com/article'], bullet.bookmarks.pluck(:link)
    assert_includes users(:one).bullets.with_urls, bullet
    assert_equal 'https://example.com/article', Nokogiri::HTML.fragment(bullet.body.to_s).at_css('.link-chip')['href']
    assert_equal 1, Nokogiri::HTML.fragment(bullet.rich_text_body.body.to_html).css('action-text-attachment').size

    bullet.update!(body: 'No link here')

    assert_empty bullet.bookmarks.reload
    assert_not_includes users(:one).bullets.with_urls, bullet
  end

  test 'converts pasted URL anchors and leaves named anchors alone' do
    bullet = create_bullet!(users(:one), body: <<~HTML)
      <p><a href="https://example.com/one">https://example.com/one</a> and
      <a href="https://example.com/two">custom label</a></p>
    HTML

    assert_equal %w[https://example.com/one https://example.com/two], bullet.bookmarks.order(:link).pluck(:link)
    rendered = Nokogiri::HTML.fragment(bullet.body.to_s)
    assert_equal 'https://example.com/one', rendered.at_css('.link-chip')['href']
    assert_equal 'custom label', rendered.at_css('a[href="https://example.com/two"]').text
    assert_nil rendered.at_css('a[href="https://example.com/two"]')['class']
  end

  test 'reuses one bookmark record for repeated URLs' do
    bullet = create_bullet!(users(:one), body: '<p>https://example.com and https://example.com</p>')

    assert_equal ['https://example.com'], bullet.bookmarks.pluck(:link)
    assert_equal 2, Nokogiri::HTML.fragment(bullet.rich_text_body.body.to_html).css('action-text-attachment').size
  end

  test 'preserves surrounding text, punctuation and URL parameters without interpreting text as HTML' do
    bullet = create_bullet!(users(:one), body: <<~HTML)
      <p>&lt;em&gt;Read &amp; save&lt;/em&gt; (https://example.com/article?a=1&amp;b=2), after.</p>
      <pre>https://example.com/code</pre>
    HTML
    rendered = Nokogiri::HTML.fragment(bullet.body.to_s)
    paragraph = rendered.at_css('p')

    assert_equal ['https://example.com/article?a=1&b=2'], bullet.bookmarks.pluck(:link)
    assert_equal '<em>Read & save</em> (', paragraph.children.first.text
    assert paragraph.text.end_with?('), after.')
    assert_nil paragraph.at_css('em')
    assert_equal 'https://example.com/code', rendered.at_css('pre').text
    assert_nil rendered.at_css('pre a')
  end

  test 'handles a copied chip, a named anchor and plain URL text together' do
    original = create_bullet!(users(:one), body: 'https://example.com/original')
    copy = create_bullet!(users(:one), body: <<~HTML)
      #{original.rich_text_body.body.to_html}
      <p><a href="https://example.com/named">Custom label</a> and https://example.com/plain</p>
    HTML
    rendered = Nokogiri::HTML.fragment(copy.body.to_s)

    assert_equal %w[https://example.com/named https://example.com/original https://example.com/plain],
                 copy.bookmarks.order(:link).pluck(:link)
    assert_equal 2, rendered.css('.link-chip').size
    assert_equal 'Custom label', rendered.at_css('a[href="https://example.com/named"]').text
    assert_not_equal original.bookmarks.first.id, copy.bookmarks.find_by!(link: 'https://example.com/original').id
  end

  test 'saved chips use their bookmark record for rendering and survive edits' do
    bullet = create_bullet!(users(:one), body: 'https://example.com/article')
    bookmark = bullet.bookmarks.first
    attachment = Nokogiri::HTML.fragment(bullet.rich_text_body.body.to_html).at_css('action-text-attachment')

    assert_equal bookmark.attachable_sgid, attachment['sgid']
    assert_nil attachment['content']

    bookmark.update!(title: 'Article')
    assert_equal 'Article', Nokogiri::HTML.fragment(bullet.body.to_s).at_css('.link-chip--name')&.text

    bullet.update!(body: "<p>Read later #{bullet.rich_text_body.body.to_html}</p>")
    assert_equal [bookmark.id], bullet.bookmarks.reload.pluck(:id)

    bullet.update!(body: 'No link here')
    assert_empty bullet.bookmarks.reload
    assert_not_includes users(:one).bullets.with_urls, bullet
  end

  test 'copies a saved chip into another bullet without moving its bookmark' do
    original = create_bullet!(users(:one), body: 'https://example.com/article')
    original.bookmarks.first.update!(title: 'Article', icon_link: 'https://example.com/favicon.ico', unfurled_at: Time.current)
    original.bookmarks.first.favicon.attach(create_blob!(filename: 'favicon.png', content_type: 'image/png'))
    copy = create_bullet!(users(:one), body: "Read #{original.rich_text_body.body.to_html}")

    assert_equal original.bookmarks.first.link, copy.bookmarks.first.link
    assert_not_equal original.bookmarks.first.id, copy.bookmarks.first.id
    assert_equal 'Article', copy.bookmarks.first.title
    assert_equal original.bookmarks.first.favicon.blob, copy.bookmarks.first.favicon.blob
    rendered = Nokogiri::HTML.fragment(copy.body.to_s)
    assert_includes rendered.at_css('.link-chip--icon')['src'], '/rails/active_storage/'
    assert_equal copy.bookmarks.first.attachable_sgid,
                 Nokogiri::HTML.fragment(copy.rich_text_body.body.to_html).at_css('action-text-attachment')['sgid']
  end

  test 'rejects a chip belonging to another user' do
    original = create_bullet!(users(:two), body: 'Private note')
    foreign_bookmark = original.bookmarks.create!(link: 'https://example.com/private', title: 'Private link')
    attachment = ActionText::Attachment.from_attachable(foreign_bookmark)
    bullet = users(:one).bullets.new(body: attachment.to_html)

    assert_no_difference 'Bullet.count' do
      assert_not bullet.save
    end
    assert_includes bullet.errors[:body], 'contains an invalid link chip'
  end

  test 'rejects a chip with an invalid signed id' do
    body = '<action-text-attachment content-type="application/vnd.dotted.link-chip" sgid="invalid"></action-text-attachment>'
    bullet = users(:one).bullets.new(body: body)

    assert_no_difference 'Bookmark.count' do
      assert_not bullet.save
    end
    assert_includes bullet.errors[:body], 'contains an invalid link chip'
  end

  test 'rejects a chip without a signed id' do
    body = '<action-text-attachment content-type="application/vnd.dotted.link-chip" content="&lt;a href=&quot;https://example.com&quot;&gt;Example&lt;/a&gt;"></action-text-attachment>'
    bullet = users(:one).bullets.new(body: body)

    assert_not bullet.save
    assert_includes bullet.errors[:body], 'contains an invalid link chip'
  end

  test 'rejects embedded HTML on a saved chip' do
    original = create_bullet!(users(:one), body: 'https://example.com')
    attachment = ActionText::Attachment.from_attachable(original.bookmarks.first).to_html
    fragment = Nokogiri::HTML.fragment(attachment)
    fragment.at_css('action-text-attachment')['content'] = '<a href="https://example.com">Different content</a>'
    bullet = users(:one).bullets.new(body: fragment.to_html)

    assert_not bullet.save
    assert_includes bullet.errors[:body], 'contains an invalid link chip'
  end
end
