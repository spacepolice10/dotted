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

  test 'tapping the bullet body selects it' do
    visit bullets_path
    assert_selector '.bullet--body', text: 'Selectable line'
    page.driver.browser.execute_cdp('Emulation.setTouchEmulationEnabled', enabled: true)
    assert page.evaluate_script("matchMedia('(any-pointer: coarse)').matches")

    page.execute_script(<<~JS)
      const body = document.querySelector('.bullet .bullet--body').getBoundingClientRect()
      document.elementFromPoint(body.right - 8, body.top + body.height / 2).click()
    JS

    assert_selector '[data-bullet-menu-target=checkbox]:checked', visible: :all
    assert_selector '.bullet-menu', visible: true
  end

  test 'selecting a partly visible bullet does not move the timeline' do
    18.times { |i| create_bullet!(@user, body: "Older line #{i}", created_at: (18 - i).minutes.ago) }
    visit bullets_path
    page.driver.browser.execute_cdp('Emulation.setTouchEmulationEnabled', enabled: true)

    point = page.evaluate_script(<<~JS)
      (() => {
        const scroller = document.querySelector('.timeline--scroller')
        scroller.scrollTop = 35
        const row = [...scroller.querySelectorAll('.bullet')].find((row) => {
          const rect = row.getBoundingClientRect()
          const top = scroller.getBoundingClientRect().top
          return rect.top < top + 60 && rect.bottom > top + 10
        })
        if (!row) return null
        const rect = row.querySelector('.bullet--select-checkbox').getBoundingClientRect()
        window.selectionScrollBefore = scroller.scrollTop
        window.selectionScrollEvents = []
        scroller.addEventListener('scroll', () => window.selectionScrollEvents.push(scroller.scrollTop))
        return { x: rect.left + rect.width / 2, y: Math.max(rect.top + rect.height / 2, scroller.getBoundingClientRect().top + 15) }
      })()
    JS
    assert point

    browser = page.driver.browser
    browser.execute_cdp('Input.dispatchTouchEvent', type: 'touchStart', touchPoints: [{ x: point['x'], y: point['y'] }])
    browser.execute_cdp('Input.dispatchTouchEvent', type: 'touchEnd', touchPoints: [])

    assert_selector '[data-bullet-menu-target=checkbox]:checked', visible: :all
    result = page.evaluate_script(<<~JS)
      ({ before: window.selectionScrollBefore,
         after: document.querySelector('.timeline--scroller').scrollTop,
         events: window.selectionScrollEvents,
         menuFocused: document.activeElement === document.querySelector('.bullet-menu') })
    JS
    assert result['menuFocused']
    assert_in_delta result['before'], result['after'], 1
    assert result['events'].all? { |position| (position - result['before']).abs <= 1 }
  end

  test 'on mobile the open menu overlays without moving the page' do
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

    assert_in_delta before['mainHeight'], after['mainHeight'], 1
    assert_in_delta before['tabbarHeight'], after['tabbarHeight'], 1
    assert_in_delta before['composerHeight'], after['composerHeight'], 1
    assert_operator after['menuTop'], :<, after['mainBottom']
  end
end

class BulletMenuDesktopSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
    create_bullet!(@user, body: 'Selectable line', created_at: Time.current)
  end

  test 'on desktop the menu overlays the page without shrinking it' do
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

    assert_in_delta before_height, metrics['mainHeight'], 1
    assert_operator metrics['menuTop'], :<, metrics['mainBottom']
  end
end
