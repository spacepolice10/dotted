# frozen_string_literal: true

require 'application_system_test_case'

class HorizontalOverflowSystemTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [390, 844]

  test 'completed bullets and status badges fit narrow pages without a composer' do
    user = users(:one)
    done = create_bullet!(user, body: 'Done')
    done.complete!
    postponed = create_bullet!(user, body: 'Postponed', last_postponed_at: Time.current)
    published = create_bullet!(user, body: 'Published')
    published.publish!
    sign_in_as(user)

    [[bullets_path(completed: true), done], [bullet_path(postponed), postponed], [bullet_path(published), published]].each do |path, bullet|
      visit path
      assert_selector "#bullet_#{bullet.id}"
      if bullet.done?
        assert_selector "#bullet_#{bullet.id}[data-bullet-done=true]"
      else
        assert_selector "#bullet_#{bullet.id} .bullet--status--#{bullet.status}"
      end
      assert_no_selector '.composer'

      [320, 390].each do |width|
        page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: width, height: 844, deviceScaleFactor: 1, mobile: true)
        metrics = page.evaluate_script(<<~JS)
          (() => ({
            viewport: document.documentElement.clientWidth,
            page: document.documentElement.scrollWidth,
            scrollerWidth: (document.querySelector('.timeline--scroller') || document.querySelector('.bullet-page')).clientWidth,
            scrollerScrollWidth: (document.querySelector('.timeline--scroller') || document.querySelector('.bullet-page')).scrollWidth
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
      assert_no_horizontal_overflow

      editor.send_keys([:command, 'a'], :backspace)
      assert_selector 'lexxy-editor.lexxy-editor--empty'
    end
  end

  private

  def assert_no_horizontal_overflow
    # Control widths animate when content appears/disappears; wait for the
    # observable layout condition rather than a fixed delay.
    metrics = nil
    page.document.synchronize(Capybara.default_max_wait_time, errors: [Capybara::ExpectationNotMet]) do
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

      unless metrics['composerScrollWidth'] <= metrics['composerWidth'] && metrics['pageScrollWidth'] <= metrics['viewportWidth']
        raise Capybara::ExpectationNotMet, metrics.inspect
      end
    end
    assert_operator metrics['composerScrollWidth'], :<=, metrics['composerWidth'], metrics.inspect
    assert_operator metrics['pageScrollWidth'], :<=, metrics['viewportWidth'], metrics.inspect
  end
end
