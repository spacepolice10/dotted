# frozen_string_literal: true

require 'application_system_test_case'

class BulletMenuMobileSystemTest < ApplicationSystemTestCase
  MOBILE_UA = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 ' \
              '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36'

  driven_by :selenium,
            using: :headless_chrome,
            screen_size: [390, 844],
            options: { name: :selenium_mobile } do |options|
    options.add_argument("--user-agent=#{MOBILE_UA}")
    options.add_argument('--use-fake-device-for-media-stream')
    options.add_argument('--use-fake-ui-for-media-stream')
  end

  setup do
    @user = users(:one)
    sign_in_as(@user)
    create_bullet!(@user, body: 'Selectable line', created_at: Time.current)
  end

  test 'text bullets select with the left checkbox while tapping the body does not select' do
    visit bullets_path
    assert_selector '.bullet--body', text: 'Selectable line'
    page.driver.browser.execute_cdp('Emulation.setTouchEmulationEnabled', enabled: true)
    assert page.evaluate_script("matchMedia('(any-pointer: coarse)').matches")

    page.execute_script(<<~JS)
      const body = document.querySelector('.bullet .bullet--body').getBoundingClientRect()
      document.elementFromPoint(body.right - 8, body.top + body.height / 2).click()
    JS

    assert_no_selector '[data-bullet-menu-target=checkbox]:checked', visible: :all
    assert_no_selector '.bullet--select-checkbox'
    find('.bullet--select-square').click
    assert_selector '[data-bullet-menu-target=checkbox]:checked', visible: :all
    assert_selector '.bullet-menu', visible: true
  end

  test 'the floating menu never scrolls or resizes the timeline' do
    25.times { |i| create_bullet!(@user, body: "Older line #{i}", created_at: (i + 1).minutes.ago) }
    visit bullets_path
    metrics = <<~JS
      (() => {
        const list = document.querySelector('.timeline--scroller')
        const rect = list.getBoundingClientRect()
        return [list.scrollTop, list.scrollHeight, rect.top, rect.height,
          document.querySelector('.timeline--scroller .bullet').getBoundingClientRect().top]
      })()
    JS
    before = page.evaluate_script(metrics)

    page.execute_script("document.querySelector('.timeline--scroller .bullet input').click()")
    assert_selector '.bullet-menu--count', text: '1 selected'
    assert_no_selector '.bullet-menu--heading', visible: :all
    assert_no_selector 'button[aria-label="Clear selection"]', visible: :all
    assert_equal before, page.evaluate_script(metrics)

    page.execute_script("document.querySelectorAll('.timeline--scroller .bullet input')[1].click()")
    assert_selector '.bullet-menu--count', text: '2 selected'
    assert_equal before, page.evaluate_script(metrics)

    find('.bullet-menu').send_keys(:escape)
    assert_no_selector '.bullet-menu'
    assert_equal before, page.evaluate_script(metrics)
  end

end

class BulletMenuDesktopSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
    create_bullet!(@user, body: 'Selectable line', created_at: Time.current)
  end

  test 'on desktop the menu floats on the right without resizing the timeline' do
    [[1400, 1400], [768, 1024], [1024, 768]].each do |width, height|
      page.driver.browser.manage.window.resize_to(width, height)
      visit bullets_path

      before_height = page.evaluate_script(
        "document.querySelector('body > main').getBoundingClientRect().height"
      )

      page.execute_script("document.querySelector('[data-bullet-menu-target=checkbox]').click()")
      assert_selector '.bullet-menu'

      metrics = page.evaluate_script(<<~JS)
        (() => {
          const main = document.querySelector('body > main').getBoundingClientRect()
          const menu = document.querySelector('.bullet-menu').getBoundingClientRect()
          return {
            mainHeight: main.height,
            mainBottom: main.bottom,
            menuTop: menu.top,
            menuRight: menu.right,
            position: getComputedStyle(document.querySelector('.bullet-menu')).position
          }
        })()
      JS

      assert_in_delta before_height, metrics['mainHeight'], 1
      assert_equal 'absolute', metrics['position']
      assert_operator metrics['menuRight'], :>, page.evaluate_script('innerWidth / 2')
      assert_selector '.composer--dock'
    end
  end
end
