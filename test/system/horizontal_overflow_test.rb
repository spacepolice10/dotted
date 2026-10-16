# frozen_string_literal: true

require 'application_system_test_case'

class HorizontalOverflowSystemTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [390, 844]

  test 'status badges do not widen the timeline without a composer' do
    user = users(:one)
    done = create_bullet!(user, body: 'Done')
    done.complete!
    postponed = create_bullet!(user, body: 'Postponed', last_postponed_at: Time.current)
    published = create_bullet!(user, body: 'Published')
    published.publish!
    sign_in_as(user)

    [bullets_path(completed: true), bullet_path(postponed), bullet_path(published)].each do |path|
      visit path
      assert_selector '.bullet--status'
      assert_no_selector '.composer'

      [320, 390].each do |width|
        page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: width, height: 844, deviceScaleFactor: 1, mobile: true)
        metrics = page.evaluate_script(<<~JS)
          (() => ({
            viewport: document.documentElement.clientWidth,
            page: document.documentElement.scrollWidth,
            scrollerWidth: document.querySelector('.timeline--scroller').clientWidth,
            scrollerScrollWidth: document.querySelector('.timeline--scroller').scrollWidth
          }))()
        JS
        assert_operator metrics['scrollerScrollWidth'], :<=, metrics['scrollerWidth'], "#{path} at #{width}px: #{metrics.inspect}"
        assert_operator metrics['page'], :<=, metrics['viewport'], "#{path} at #{width}px: #{metrics.inspect}"
      end
    end
  end

  test 'collapsed composer controls do not create horizontal scrolling' do
    sign_in_as(users(:one))
    visit bullets_path

    [320, 390].each do |width|
      page.driver.browser.execute_cdp(
        'Emulation.setDeviceMetricsOverride',
        width: width, height: 844, deviceScaleFactor: 1, mobile: true
      )

      assert_no_horizontal_overflow

      editor = find('#bullet_composer lexxy-editor .lexxy-editor__content')
      editor.send_keys('A thought')
      assert_selector 'lexxy-editor:not(.lexxy-editor--empty)'
      sleep 0.25
      assert_no_horizontal_overflow

      editor.send_keys([:command, 'a'], :backspace)
      assert_selector 'lexxy-editor.lexxy-editor--empty'
    end
  end

  private

  def assert_no_horizontal_overflow
    metrics = page.evaluate_script(<<~JS)
      (() => {
        const composer = document.querySelector('.composer')
        const root = document.documentElement
        return {
          composerWidth: composer.clientWidth,
          composerScrollWidth: composer.scrollWidth,
          viewportWidth: root.clientWidth,
          pageScrollWidth: root.scrollWidth
        }
      })()
    JS

    assert_operator metrics['composerScrollWidth'], :<=, metrics['composerWidth'], metrics.inspect
    assert_operator metrics['pageScrollWidth'], :<=, metrics['viewportWidth'], metrics.inspect
  end
end
