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

  test "floating menu stays expanded while selecting more bullets" do
    visit bullets_path
    page.execute_script("document.querySelector('[data-bullet-menu-target=checkbox]').click()")
    assert_selector ".bullet-menu--card"

    assert_equal "auto", page.evaluate_script(
      "getComputedStyle(document.querySelector('.bullet-menu')).pointerEvents"
    )
    assert_equal "auto", page.evaluate_script(
      "getComputedStyle(document.querySelector('.bullet-menu--card')).pointerEvents"
    )
    page.document.synchronize do
      running = page.evaluate_script("document.querySelector('.bullet-menu').getAnimations().some(animation => animation.playState == 'running')")
      raise Capybara::ExpectationNotMet if running
    end
    pill = page.evaluate_script(<<~JS)
      (() => {
        const card = document.querySelector('.bullet-menu--card').getBoundingClientRect();
        const count = document.querySelector('.bullet-menu--count').getBoundingClientRect();
        return { offset: Math.abs((card.left + card.right - count.left - count.right) / 2),
                 bottom: count.bottom, cardTop: card.top, top: count.top };
      })()
    JS
    assert_operator pill['offset'], :<=, 2
    assert_operator pill['bottom'], :<, pill['cardTop']
    assert_operator pill['top'], :>=, 0
    assert_no_selector '.bullet-menu--heading', visible: :all
    assert_no_selector 'button[aria-label="Clear selection"]', visible: :all

    clicked_bullet = page.evaluate_script(<<~JS)
      (() => {
        const cardTop = document.querySelector('.bullet-menu--card').getBoundingClientRect().top;
        const bullet = [...document.querySelectorAll('.bullet')].find((row) => {
          const rect = row.getBoundingClientRect();
          return rect.top >= 0 && rect.bottom < cardTop && !row.querySelector('input').checked;
        });
        if (!bullet) return false;
        const rect = bullet.querySelector('.bullet--body').getBoundingClientRect();
        const hit = document.elementFromPoint(rect.left + rect.width / 2, rect.top + rect.height / 2);
        if (!bullet.contains(hit)) return false;
        bullet.querySelector("[data-bullet-menu-target=checkbox]").click();
        return true;
      })()
    JS
    assert clicked_bullet, "expected an uncovered bullet to receive a tap"
    assert_selector '[data-bullet-menu-target=checkbox]:checked', count: 2, visible: :all

    assert_selector '.bullet-menu--actions', visible: true
    assert_selector '.bullet-menu--count', text: '2 selected'

    page.execute_script("document.querySelectorAll('[data-bullet-menu-target=checkbox]')[2].click()")
    assert_selector '.bullet-menu--count', text: '3 selected'
    assert_selector '.bullet-menu--actions', visible: true
    assert_no_selector '.bullet-menu details, .bullet-menu summary', visible: :all
  end
end
