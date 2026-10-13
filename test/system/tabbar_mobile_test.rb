# frozen_string_literal: true

require 'application_system_test_case'

class TabbarMobileSystemTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [390, 844]

  setup do
    sign_in_as(users(:one))
    page.driver.browser.execute_cdp('Emulation.setTouchEmulationEnabled', enabled: true)
    visit bullets_path
    assert page.evaluate_script("matchMedia('(pointer: coarse)').matches")
  end

  test 'the tabbar uses one bottom inset and gives its space to the focused composer' do
    before = layout_metrics
    assert_in_delta before['bottomInset'], before['tabbarGap'], 1
    assert_in_delta before['tabbarGap'] + before['tabbarHeight'], before['dockGap'], 3

    page.execute_script("document.querySelector('lexxy-editor .lexxy-editor__content').focus()")
    assert_selector '.composer--dock:focus-within'
    wait_for_tabbar_offscreen

    focused = layout_metrics
    assert_equal 'none', focused['pointerEvents']
    assert_in_delta before['bottomInset'], focused['dockGap'], 2
    assert_operator focused['tabbarTop'], :>=, focused['viewportHeight'] - 1

    page.execute_script("document.activeElement.blur()")
    wait_for_tabbar_onscreen
  end

  test 'a larger PWA safe area moves the tabbar and composer by the same amount' do
    page.execute_script("document.documentElement.style.setProperty('--tabbar-bottom', '34px')")

    inset = layout_metrics
    assert_in_delta 34, inset['tabbarGap'], 1
    assert_in_delta inset['tabbarGap'] + inset['tabbarHeight'], inset['dockGap'], 3

    page.execute_script("document.querySelector('lexxy-editor .lexxy-editor__content').focus()")
    assert_selector '.composer--dock:focus-within'
    wait_for_tabbar_offscreen

    focused = layout_metrics
    assert_equal 'none', focused['pointerEvents']
    assert_in_delta 34, focused['dockGap'], 1
  end

  test 'touching submit preserves editor focus until submission starts' do
    editor = find('#bullet_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('Touch sequence')
    page.execute_script(<<~JS)
      window.composerTouchEvents = []
      for (const type of ['pointerdown', 'touchstart', 'focusout', 'pointerup', 'touchend', 'click', 'submit']) {
        document.addEventListener(type, (event) => {
          if (!event.target.closest('#bullet_composer')) return
          const button = document.querySelector('#bullet_composer .composer--submit-button')
          window.composerTouchEvents.push({
            type,
            target: event.target.tagName,
            focused: document.activeElement?.className,
            top: button.getBoundingClientRect().top,
            bottom: button.getBoundingClientRect().bottom
          })
        }, true)
      }
    JS

    rect = page.evaluate_script(<<~JS)
      (() => {
        const rect = document.querySelector('#bullet_composer .composer--submit-button').getBoundingClientRect()
        return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 }
      })()
    JS
    browser = page.driver.browser
    browser.execute_cdp('Input.dispatchTouchEvent', type: 'touchStart', touchPoints: [{ x: rect['x'], y: rect['y'] }])
    sleep 0.15
    browser.execute_cdp('Input.dispatchTouchEvent', type: 'touchEnd', touchPoints: [])

    assert_selector '#timeline .bullet', text: 'Touch sequence'
    events = page.evaluate_script('window.composerTouchEvents')
    pointerdown = events.index { |event| event['type'] == 'pointerdown' }
    assert pointerdown
    assert_nil(events[0...pointerdown].find { |event| event['type'] == 'focusout' })
    assert(events.any? { |event| event['type'] == 'touchstart' })
  end

  test 'ordinary pages keep a small scroll buffer above the floating tabbar' do
    visit user_path
    assert_selector 'body > main'

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const tabbar = document.querySelector('.tabbar--navigation').getBoundingClientRect()
        const main = document.querySelector('body > main')
        return {
          padding: parseFloat(getComputedStyle(main).paddingBottom),
          clearance: innerHeight - tabbar.top
        }
      })()
    JS

    assert_operator metrics['padding'], :>, metrics['clearance']
    assert_operator metrics['padding'] - metrics['clearance'], :<, 25

    visit collections_path
    assert_selector '.tabbar--navigation.tabbar--back'
    back = page.evaluate_script(<<~JS)
      (() => {
        const tabbar = document.querySelector('.tabbar--navigation')
        return {
          gap: innerHeight - tabbar.getBoundingClientRect().bottom,
          inset: parseFloat(getComputedStyle(tabbar).bottom)
        }
      })()
    JS
    assert_in_delta back['inset'], back['gap'], 1
  end

  private

  def wait_for_tabbar_offscreen
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    until layout_metrics['tabbarTop'] >= layout_metrics['viewportHeight'] - 1
      flunk 'tabbar did not move offscreen' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.05
    end
  end

  def wait_for_tabbar_onscreen
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    until layout_metrics['tabbarTop'] < layout_metrics['viewportHeight'] - 1
      flunk 'tabbar did not return onscreen' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.05
    end
    assert_equal 'auto', layout_metrics['pointerEvents']
  end

  def layout_metrics
    page.evaluate_script(<<~JS)
      (() => {
        const tabbar = document.querySelector('.tabbar--navigation')
        const dock = document.querySelector('.composer--dock')
        const rect = tabbar.getBoundingClientRect()
        const style = getComputedStyle(tabbar)
        return {
          bottomInset: parseFloat(style.bottom),
          tabbarGap: innerHeight - rect.bottom,
          tabbarTop: rect.top,
          tabbarHeight: rect.height,
          viewportHeight: innerHeight,
          dockGap: parseFloat(getComputedStyle(dock).marginBottom),
          pointerEvents: style.pointerEvents
        }
      })()
    JS
  end
end
