# frozen_string_literal: true

require "application_system_test_case"

class BulletMenuFloatingCardSystemTest < ApplicationSystemTestCase
  MOBILE_UA = "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 " \
              "(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36"

  driven_by :selenium,
            using: :headless_chrome,
            screen_size: [390, 844],
            options: { name: :selenium_mobile } do |options|
    options.add_argument("--user-agent=#{MOBILE_UA}")
  end

  setup do
    @user = users(:one)
    sign_in_as(@user)
    8.times { |i| create_bullet!(@user, body: "Selectable line #{i}", created_at: Time.current) }
  end

  test "expanded card leaves uncovered bullets clickable and collapses into a pill" do
    visit bullets_path
    page.execute_script("document.querySelector('[data-bullet-menu-target=checkbox]').click()")
    assert_selector ".bullet-menu--card[open]"

    assert_equal "none", page.evaluate_script(
      "getComputedStyle(document.querySelector('.bullet-menu')).pointerEvents"
    )
    assert_equal "auto", page.evaluate_script(
      "getComputedStyle(document.querySelector('.bullet-menu--card')).pointerEvents"
    )
    center_offset = page.evaluate_script(<<~JS)
      (() => {
        const card = document.querySelector('.bullet-menu--card').getBoundingClientRect();
        const button = document.querySelector('.bullet-menu--card button[aria-label="Clear selection"]').getBoundingClientRect();
        return Math.abs((card.left + card.right - button.left - button.right) / 2);
      })()
    JS
    assert_operator center_offset, :<=, 2, "Clear selection should be centered in the card"

    clicked_bullet = page.evaluate_script(<<~JS)
      (() => {
        const cardTop = document.querySelector('.bullet-menu--card').getBoundingClientRect().top;
        const bullet = [...document.querySelectorAll('.bullet')].find((row) => {
          const rect = row.getBoundingClientRect();
          return rect.top >= 0 && rect.bottom < cardTop && !row.querySelector('input').checked;
        });
        if (!bullet) return false;
        const rect = bullet.querySelector('.bullet--marker').getBoundingClientRect();
        const hit = document.elementFromPoint(rect.left + rect.width / 2, rect.top + rect.height / 2);
        if (!bullet.contains(hit)) return false;
        hit.click();
        return true;
      })()
    JS
    assert clicked_bullet, "expected an uncovered bullet to receive a tap"
    assert_selector '[data-bullet-menu-target=checkbox]:checked', count: 2, visible: :all

    find('.bullet-menu--card summary').click
    assert_selector '.bullet-menu--card:not([open])'
    assert_no_selector '.bullet-menu--actions', visible: true
    assert_selector '.bullet-menu--card summary', text: '2 selected', visible: true

    page.execute_script("document.querySelectorAll('[data-bullet-menu-target=checkbox]')[2].click()")
    assert_selector '.bullet-menu--card:not([open])'
    assert_selector '.bullet-menu--card summary', text: '3 selected', visible: true

    find('.bullet-menu--card summary').click
    assert_selector '.bullet-menu--card[open]'
    assert_selector '.bullet-menu--actions', visible: true
  end
end
