# frozen_string_literal: true

require 'application_system_test_case'

class BulletKeyboardFocusSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
    create_bullet!(@user, body: 'Selectable line', created_at: Time.current)
  end

  test 'focusing the select checkbox outlines the whole bullet body' do
    visit bullets_path

    # Real typing puts the page in keyboard modality, so a subsequent
    # programmatic focus matches :focus-visible the way Tab would.
    find('body').send_keys(:tab)
    page.execute_script("document.querySelector('[data-bullet-menu-target=checkbox]').focus()")

    assert page.evaluate_script("document.querySelector('[data-bullet-menu-target=checkbox]').matches(':focus-visible')"),
      'expected the select checkbox to match :focus-visible'

    outline_style = page.evaluate_script(
      "getComputedStyle(document.querySelector('.bullet .bullet--body')).outlineStyle"
    )
    assert_equal 'solid', outline_style,
      'expected the bullet body to show a solid outline when its select checkbox is focused'
  end

  test 'only the select checkbox and links are tabbable inside a bullet' do
    visit bullets_path

    tabbable = page.evaluate_script(
      "[...document.querySelectorAll('.bullet')].map((bullet) => [...bullet.querySelectorAll('a[href], button, input, [tabindex]:not([tabindex=\"-1\"])')].map((el) => el.matches('[data-bullet-menu-target=checkbox]') ? 'checkbox' : el.tagName.toLowerCase()))"
    )

    assert_equal [['checkbox']], tabbable
  end
end
