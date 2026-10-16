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

  test 'opening and closing the menu keeps the newest bullet above the dock' do
    18.times { |i| create_bullet!(@user, body: "Older line #{i}", created_at: (18 - i).minutes.ago) }
    visit bullets_path
    assert_selector '.bullet--body', text: 'Selectable line'

    before = page.evaluate_script("document.querySelector('.timeline--scroller').scrollTop")
    page.execute_script("document.querySelector('.timeline--scroller .bullet:last-of-type input').click()")
    assert_selector '.bullet-menu'

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const list = document.querySelector('.timeline--scroller')
        const rows = list.querySelectorAll('.bullet')
        return { rowBottom: rows[rows.length - 1].getBoundingClientRect().bottom,
                 listBottom: list.getBoundingClientRect().bottom,
                 scrollTop: list.scrollTop }
      })()
    JS
    assert_operator metrics['rowBottom'], :<=, metrics['listBottom']
    assert_operator metrics['scrollTop'], :>, before

    find('button[aria-label="Clear selection"]').click
    assert_no_selector '.bullet-menu'
    assert_in_delta before, page.evaluate_script(
      "document.querySelector('.timeline--scroller').scrollTop"
    ), 1
  end

  test 'on mobile the menu sits below and shrinks the timeline' do
    visit bullets_path

    before = page.evaluate_script(<<~JS)
      (() => {
        const main = document.querySelector('body > main').getBoundingClientRect()
        const tabbar = document.querySelector('.tabbar--navigation')
        const composer = document.querySelector('.composer--dock')
        return {
          mainHeight: main.height,
          tabbarHeight: tabbar ? tabbar.getBoundingClientRect().height : null,
          composerHeight: composer ? composer.getBoundingClientRect().height : null
        }
      })()
    JS

    page.execute_script("document.querySelector('[data-bullet-menu-target=checkbox]').click()")
    assert_selector '.bullet-menu'

    after = page.evaluate_script(<<~JS)
      (() => {
        const main = document.querySelector('body > main').getBoundingClientRect()
        const menu = document.querySelector('.bullet-menu').getBoundingClientRect()
        const tabbar = document.querySelector('.tabbar--navigation')
        const composer = document.querySelector('.composer--dock')
        return {
          mainHeight: main.height,
          mainBottom: main.bottom,
          menuTop: menu.top,
          tabbarHeight: tabbar ? tabbar.getBoundingClientRect().height : null,
          composerHeight: composer ? composer.getBoundingClientRect().height : null
        }
      })()
    JS

    assert_operator after['mainHeight'], :<, before['mainHeight']
    assert_in_delta before['tabbarHeight'], after['tabbarHeight'], 1
    assert_equal 0, after['composerHeight']
    assert_no_selector '.composer--dock'

    find('button[aria-label="Clear selection"]').click
    assert_selector '.composer--dock'
    assert_in_delta before['mainHeight'], page.evaluate_script(
      "document.querySelector('body > main').getBoundingClientRect().height"
    ), 1
    assert_in_delta after['mainBottom'], after['menuTop'], 1
  end
end

class BulletMenuDesktopSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
    create_bullet!(@user, body: 'Selectable line', created_at: Time.current)
  end

  test 'on desktop the menu sits below and shrinks the timeline' do
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
          menuTop: menu.top
        }
      })()
    JS

    assert_operator metrics['mainHeight'], :<, before_height
    assert_in_delta metrics['mainBottom'], metrics['menuTop'], 1
  end
end
