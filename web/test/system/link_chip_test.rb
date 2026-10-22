# frozen_string_literal: true

require 'application_system_test_case'

class LinkChipTest < ApplicationSystemTestCase
  test 'a pasted URL remains editable until save and then becomes a chip' do
    sign_in_as(users(:one))
    visit bullets_path

    page.execute_script(<<~JS)
      const editor = document.querySelector('#bullet_composer lexxy-editor .lexxy-editor__content')
      editor.focus()
      const clipboardData = new DataTransfer()
      clipboardData.setData('text/plain', 'https://example.com/article')
      editor.dispatchEvent(new ClipboardEvent('paste', { bubbles: true, cancelable: true, clipboardData }))
    JS

    assert_selector '#bullet_composer a[href="https://example.com/article"]'
    assert_no_selector '#bullet_composer .link-chip'
    assert_empty Bookmark.where(link: 'https://example.com/article')

    find('#bullet_composer .composer--submit-button').click

    assert_selector '#timeline .bullet .link-chip[href="https://example.com/article"]', text: 'example.com'
    assert_equal '_blank', find('#timeline .bullet .link-chip')[:target]
    assert_selector '#timeline .bullet .link-chip--open-icon .icon'
    assert_equal ['https://example.com/article'], users(:one).bullets.order(:id).last.bookmarks.pluck(:link)
  end

  test 'a named link stays an ordinary link and is indexed' do
    create_bullet!(users(:one), body: '<p>Read <a href="https://example.com/article">this article</a></p>')
    sign_in_as(users(:one))
    visit bullets_path

    assert_selector '#timeline .bullet--body a[href="https://example.com/article"]', text: 'this article'
    assert_no_selector '#timeline .bullet--body .link-chip'
    assert_native_link_click('#timeline .bullet--body a[href="https://example.com/article"]')
  end

  private

  def assert_native_link_click(selector)
    page.execute_script(<<~JS)
      window.linkClicks = 0
      document.querySelector(#{selector.to_json}).addEventListener('click', event => {
        event.preventDefault()
        window.linkClicks++
      })
    JS

    find(selector).click

    assert_equal 1, page.evaluate_script('window.linkClicks')
    assert_no_selector '[data-bullet-menu-target=checkbox]:checked', visible: :all
  end
end
