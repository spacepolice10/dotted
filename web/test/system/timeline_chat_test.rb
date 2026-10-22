# frozen_string_literal: true

require 'application_system_test_case'

class TimelineChatSystemTest < ApplicationSystemTestCase
  PAGE = Bullet::Pageable::PAGE_SIZE

  setup do
    @user = users(:one)
    sign_in_as(@user)
    # Keep a 20-row page outside the older-page prefetch range until we scroll.
    @original_window_size = page.current_window.size
    page.current_window.resize_to(1400, 800)
    @list = '#timeline'
  end

  teardown do
    page.current_window.resize_to(*@original_window_size) if @original_window_size
  end

  test 'the timeline opens at the newest bullet with older ones left off screen' do
    create_lines(70)

    visit bullets_path

    assert_selector "#{@list} .bullet", count: PAGE
    assert_text 'Line 69'
    assert_no_text 'Line 0'
    assert_pinned_to_bottom
  end

  test 'scrolling to the top loads older pages without moving the read row' do
    create_lines_on_dates(PAGE, 3)
    visit bullets_path
    assert_selector "#{@list} .bullet", count: PAGE

    # First trip to the top fills the scrollport (short pages keep the trigger
    # intersecting). Anchor preservation only applies once we already overflow.
    scroll_to_top
    wait_for_stable_bullet_count(minimum: PAGE * 2)

    assert_selector '.timeline--load-more-trigger'
    previous = page.all("#{@list} .bullet").size
    anchor = find("#{@list} .bullet", match: :first)[:id]
    scroll_to_top
    before = row_top(anchor)

    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    while page.all("#{@list} .bullet").size <= previous &&
          Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      sleep 0.05
    end

    assert_operator page.all("#{@list} .bullet").size, :>, previous
    assert_in_delta before, row_top(anchor), 2
  end

  test 'pages within one date merge into a single section' do
    create_lines(PAGE + 5)
    visit bullets_path
    assert_selector "#{@list} .bullet", count: PAGE

    scroll_to_top

    assert_selector "#{@list} .bullet", count: PAGE + 5
    assert_selector '#timeline_section_current_date', count: 1
    assert_no_selector '[data-timeline-count]'
    assert_selector '.timeline--section-header a', text: 'Press to show all the bullets'
    ids = page.all("#{@list} .bullet").map { |row| row[:id] }
    assert_equal ids.uniq, ids
  end

  test 'a short timeline keeps bullets on the composer edge' do
    create_lines(2)
    visit bullets_path

    assert_selector "#{@list} .bullet", count: 2
    gap = page.evaluate_script(<<~JS)
      (() => {
        const scroller = document.querySelector('.timeline--scroller')
        const clearance = parseFloat(getComputedStyle(scroller).scrollPaddingBottom) || 0
        const last = [...scroller.querySelectorAll('.bullet')].pop()
        const sectionPadding = parseFloat(getComputedStyle(last.parentElement).paddingBottom) || 0
        return Math.abs((scroller.getBoundingClientRect().bottom - clearance - sectionPadding) - last.getBoundingClientRect().bottom)
      })()
    JS
    assert_operator gap, :<=, 2, 'expected the short list to sit on the bottom of the scroller'
  end

  test 'a short text bullet keeps the minimum card width' do
    create_lines(1)
    visit bullets_path

    widths = page.evaluate_script(<<~JS)
      (() => {
        const bullet = document.querySelector('#timeline .bullet')
        const body = bullet.querySelector('.bullet--body')
        const styles = getComputedStyle(bullet)
        const available = bullet.getBoundingClientRect().width - parseFloat(styles.paddingLeft) - parseFloat(styles.paddingRight)
        const minimum = 35 * parseFloat(getComputedStyle(document.documentElement).fontSize)
        return [body.getBoundingClientRect().width, Math.min(minimum, available)]
      })()
    JS

    assert_operator widths.first, :>=, widths.last - 1
  end

  test 'rich text lists keep their markers in bullets' do
    create_bullet!(@user, body: '<ul><li>Apples</li></ul><ol><li>First</li></ol>')
    visit bullets_path

    styles = page.evaluate_script(<<~JS)
      [...document.querySelectorAll('#timeline .bullet--body .lexxy-content li')]
        .map((item) => getComputedStyle(item).listStyleType)
    JS
    assert_equal %w[disc decimal], styles
  end

  test 'completed bullets are available in the completed timeline' do
    create_bullet!(@user, body: 'Finished today').complete!
    visit bullets_path(completed: true)

    assert_selector '#timeline_section_current_date .bullet', text: 'Finished today'
  end

  test 'the older trigger disappears once the whole timeline is loaded' do
    create_lines(PAGE)
    create_bullet!(@user, body: 'Previous date', pops_on: Date.current - 1)
    visit bullets_path
    assert_selector '.timeline--load-more-trigger'

    scroll_to_top

    assert_no_selector '.timeline--load-more-trigger'
    assert_selector "#{@list} .bullet", count: PAGE + 1
    assert_text 'Previous date'
  end

  test 'sending a bullet keeps the reader at the newest row' do
    create_lines(70)
    visit bullets_path

    editor = find('#bullet_composer lexxy-editor .lexxy-editor__content')
    editor.click
    editor.send_keys('Fresh line')
    # Default type is Text — desktop send is Cmd/Ctrl+Enter.
    editor.send_keys([modifier_key, :enter])

    assert_text 'Fresh line'
    assert_pinned_to_bottom
  end

  test 'sending a bullet while reading older entries scrolls to the newest row' do
    create_lines(70)
    visit bullets_path
    assert_selector "#{@list} .bullet", count: PAGE

    scroll_to_top

    editor = find('#bullet_composer lexxy-editor .lexxy-editor__content')
    editor.click
    editor.send_keys('Fresh line from above')
    find('#bullet_composer .composer--submit-button').click

    assert_selector '#timeline .bullet:not(.bullet--pending)', text: 'Fresh line from above'
    assert_pinned_to_bottom
    gap = page.evaluate_script(<<~JS)
      (() => {
        const scroller = document.querySelector('.timeline--scroller')
        const last = scroller.querySelector('.timeline--section:last-of-type > .bullet:last-child')
        const clearance = parseFloat(getComputedStyle(scroller).scrollPaddingBottom) || 0
        const sectionPadding = parseFloat(getComputedStyle(last.parentElement).paddingBottom) || 0
        return (scroller.getBoundingClientRect().bottom - last.getBoundingClientRect().bottom) - clearance - sectionPadding
      })()
    JS
    assert_in_delta 0, gap, 2
  end

  test 'sending scrolls once for pending and preserves rich text layout through replacement' do
    create_lines(PAGE)
    visit bullets_path
    hold_pending_replacement
    track_timeline_scroll_calls

    body = (1..8).map { |index| "<p>Paragraph #{index} with <strong>formatted text</strong>.</p>" }.join
    page.execute_script("document.querySelector('#bullet_composer lexxy-editor').value = #{body.to_json}")
    find('#bullet_composer .composer--submit-button').click

    assert_selector '#timeline .bullet--pending .lexxy-content p', count: 8
    assert_pinned_to_bottom
    pending = newest_row_metrics
    assert_equal 1, timeline_scroll_calls

    release_pending_replacement
    assert_selector '#timeline .bullet:not(.bullet--pending) .lexxy-content p', text: 'Paragraph 8'
    wait_for_animation_frames

    saved = newest_row_metrics
    assert_equal 1, timeline_scroll_calls
    assert_in_delta pending['height'], saved['height'], 1
    assert_in_delta pending['top'], saved['top'], 1
    assert_in_delta pending['scrollTop'], saved['scrollTop'], 1
    assert_pinned_to_bottom
  end

  test 'pending replacement and later layout changes never pull the reader back down' do
    create_lines(PAGE)
    visit bullets_path
    hold_pending_replacement
    track_timeline_scroll_calls
    editor = find('#bullet_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('Read while saving')
    find('#bullet_composer .composer--submit-button').click
    assert_selector '#timeline .bullet--pending'
    assert_pinned_to_bottom

    # No touch/wheel event is needed to "release" anything: there is no anchor.
    page.execute_script("document.querySelector('.timeline--scroller').scrollTop -= 200")
    wait_for_animation_frames
    top = newest_row_metrics['scrollTop']
    assert_operator distance_from_bottom, :>, 100

    release_pending_replacement
    assert_selector '#timeline .bullet:not(.bullet--pending)', text: 'Read while saving'
    wait_for_animation_frames
    assert_in_delta top, newest_row_metrics['scrollTop'], 1

    page.execute_script(<<~JS)
      const scroller = document.querySelector('.timeline--scroller')
      scroller.querySelector('.timeline--section:last-of-type > .bullet:last-child').style.minHeight = '300px'
      scroller.style.maxHeight = '400px'
      window.visualViewport?.dispatchEvent(new Event('resize'))
    JS
    wait_for_animation_frames
    assert_in_delta top, newest_row_metrics['scrollTop'], 1
    assert_equal 1, timeline_scroll_calls
  end

  test 'a picture pending row reserves its saved layout without another scroll' do
    create_lines(PAGE)
    visit bullets_path
    hold_pending_replacement
    track_timeline_scroll_calls
    path = Rails.root.join("tmp/scroll-image-#{SecureRandom.hex(4)}.png")
    File.binwrite(path, Base64.decode64(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
    ))

    attach_file('bullet[file]', path, make_visible: true)
    assert_selector '#timeline .bullet--pending .attachment--preview-icon'
    assert_no_selector '#timeline .bullet--pending img'
    pending = newest_row_metrics
    assert_equal 1, timeline_scroll_calls

    release_pending_replacement
    assert_selector '#timeline .bullet:not(.bullet--pending) .attachment--preview img'
    wait_for_animation_frames
    saved = newest_row_metrics
    assert_equal 1, timeline_scroll_calls
    assert_in_delta pending['height'], saved['height'], 1
    assert_in_delta pending['top'], saved['top'], 1
    assert_in_delta pending['scrollTop'], saved['scrollTop'], 1
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test 'a non-picture attachment keeps its icon card and position through saving' do
    create_lines(PAGE)
    visit bullets_path
    hold_pending_replacement
    track_timeline_scroll_calls
    path = Rails.root.join("tmp/reference-#{SecureRandom.hex(4)}.txt")
    File.write(path, 'Reference material')

    attach_file('bullet[file]', path, make_visible: true)
    assert_selector '#timeline .bullet--pending .attachment--preview-icon .icon[style*="--icon-file"]'
    assert_selector '#timeline .bullet--pending .bullet--select-checkbox'
    assert_no_selector '#timeline .bullet--pending img'
    pending = newest_row_metrics

    release_pending_replacement
    saved_row = '#timeline .bullet:not(.bullet--pending):last-child'
    assert_selector "#{saved_row} .attachment--preview-icon"
    assert_selector "#{saved_row} .attachment--preview-name", text: File.basename(path)
    wait_for_animation_frames
    saved = newest_row_metrics
    assert_in_delta pending['height'], saved['height'], 1
    assert_in_delta pending['top'], saved['top'], 1
    assert_in_delta pending['scrollTop'], saved['scrollTop'], 1
    assert_equal 1, timeline_scroll_calls

    assert_operator page.evaluate_script("document.querySelector('#{saved_row} .attachment--preview-icon .icon-wrap').getBoundingClientRect().width"), :>=, 40
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: 320, height: 844, deviceScaleFactor: 1, mobile: true)
    %w[light dark].each do |theme|
      page.driver.browser.execute_cdp('Emulation.setEmulatedMedia', features: [{ name: 'prefers-color-scheme', value: theme }])
      wait_for_animation_frames
      assert_operator page.evaluate_script('document.documentElement.scrollWidth'), :<=,
                      page.evaluate_script('document.documentElement.clientWidth')
    end

    download = find("#{saved_row} a[aria-label='Download #{File.basename(path)}']")
    assert_equal 'false', download['data-turbo']
    assert_includes URI.decode_www_form(URI.parse(download[:href]).query.to_s), %w[disposition attachment]
    find("#{saved_row} .attachment--preview-name").click
    assert_selector "#{saved_row} [data-bullet-menu-target=checkbox]:checked", visible: :all
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test 'show all opens a timeline containing the full date' do
    create_lines(PAGE + 5)
    visit bullets_path

    assert_selector '#timeline .bullet', count: PAGE
    assert_selector '.timeline--load-more-trigger'
    find('#timeline_section_current_date a', text: 'Press to show all the bullets').click

    assert_selector '#timeline .bullet', count: PAGE + 5
    assert_no_selector '#timeline_section_current_date a', text: 'Press to show all the bullets'
    assert_selector '#timeline_section_current_date', count: 1
    assert_current_path bullets_path(from: Date.current.iso8601, to: Date.current.iso8601)
  end

  test 'older bullets load under their own day heading' do
    create_bullet!(@user, body: 'Today line', pops_on: Date.current)
    create_bullet!(@user, body: 'Old line', pops_on: Date.current - 10.days)

    visit bullets_path

    assert_selector '#timeline_section_current_date h2.pill', text: 'Today'
    scroll_to_top
    assert_selector '.timeline--section .bullet', text: 'Old line'
  end

  private

  def track_timeline_scroll_calls
    page.execute_script(<<~JS)
      const scroller = document.querySelector('.timeline--scroller')
      scroller.style.maxHeight = '500px'
      scroller.pendingScrollCalls = 0
      const originalScrollTo = scroller.scrollTo.bind(scroller)
      scroller.scrollTo = (...args) => {
        scroller.pendingScrollCalls += 1
        return originalScrollTo(...args)
      }
    JS
  end

  def timeline_scroll_calls
    page.evaluate_script("document.querySelector('.timeline--scroller').pendingScrollCalls")
  end

  def newest_row_metrics
    page.evaluate_script(<<~JS)
      (() => {
        const scroller = document.querySelector('.timeline--scroller')
        const last = scroller.querySelector('.timeline--section:last-of-type > .bullet:last-child')
        const rect = last.getBoundingClientRect()
        return { height: rect.height, top: rect.top, scrollTop: scroller.scrollTop }
      })()
    JS
  end

  def wait_for_animation_frames
    page.driver.browser.execute_async_script('requestAnimationFrame(() => requestAnimationFrame(arguments[0]))')
  end

  def hold_pending_replacement
    page.execute_script(<<~JS)
      window.releasePendingReplacement = null
      document.addEventListener('turbo:before-stream-render', (event) => {
        if (!event.target.getAttribute('target')?.startsWith('bullet_client_')) return
        const render = event.detail.render
        event.detail.render = async (stream) => {
          await new Promise((resolve) => { window.releasePendingReplacement = resolve })
          await render(stream)
        }
      }, { once: true })
    JS
  end

  def release_pending_replacement
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    until page.evaluate_script('typeof window.releasePendingReplacement === "function"')
      flunk 'pending replacement never arrived' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.05
    end
    page.execute_script('window.releasePendingReplacement()')
  end

  def assert_pinned_to_bottom
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    gap = distance_from_bottom

    while gap > 2 && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      sleep 0.05
      gap = distance_from_bottom
    end

    assert_operator gap, :<=, 2, 'expected the timeline to rest on the newest bullet'
  end

  def wait_for_stable_bullet_count(minimum:)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    previous = nil
    stable_since = nil

    loop do
      current = page.all("#{@list} .bullet", visible: :all).size
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      if current >= minimum && current == previous
        stable_since ||= now
        return current if now - stable_since >= 0.3
      else
        stable_since = nil
      end

      break if now >= deadline

      previous = current
      sleep 0.1
    end

    flunk "bullet count did not stabilize at >= #{minimum} (last=#{previous})"
  end

  def create_lines(count)
    Array.new(count) do |index|
      create_bullet!(@user, body: "Line #{index}", created_at: (count - index).minutes.ago)
    end
  end

  def create_lines_on_dates(count_per_date, date_count)
    date_count.times do |date_index|
      count_per_date.times do |index|
        create_bullet!(@user, body: "Date #{date_index} line #{index}", pops_on: Date.current - date_index)
      end
    end
  end

  def scroll_to_top
    page.execute_script("document.querySelector('.timeline--scroller').scrollTop = 0")
  end

  def distance_from_bottom
    page.evaluate_script(<<~JS)
      (() => {
        const scroller = document.querySelector('.timeline--scroller')
        return scroller.scrollHeight - scroller.scrollTop - scroller.clientHeight
      })()
    JS
  end

  def row_top(id)
    page.evaluate_script("document.getElementById('#{id}').getBoundingClientRect().top")
  end

  def modifier_key
    RUBY_PLATFORM.match?(/darwin/i) ? :meta : :control
  end
end
