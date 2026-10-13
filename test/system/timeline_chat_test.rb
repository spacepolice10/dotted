# frozen_string_literal: true

require 'application_system_test_case'

class TimelineChatSystemTest < ApplicationSystemTestCase
  PAGE = Bullet::Pageable::PAGE_SIZE

  setup do
    @user = users(:one)
    sign_in_as(@user)
    @list = '#timeline'
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
    create_lines(70)
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

  test 'the older trigger disappears once the whole timeline is loaded' do
    create_lines(PAGE + 5)
    visit bullets_path
    assert_selector '.timeline--load-more-trigger'

    scroll_to_top

    assert_no_selector '.timeline--load-more-trigger'
    assert_selector "#{@list} .bullet", count: PAGE + 5
    assert_text 'Line 0'
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

    page.execute_script(<<~JS)
      const scroller = document.querySelector('.timeline--scroller')
      scroller.pendingScrollCalls = 0
      const originalScrollTo = scroller.scrollTo.bind(scroller)
      scroller.scrollTo = (...args) => {
        scroller.pendingScrollCalls += 1
        return originalScrollTo(...args)
      }
    JS

    editor = find('#bullet_composer lexxy-editor .lexxy-editor__content')
    editor.click
    editor.send_keys('Fresh line from above')
    find('#bullet_composer .composer--submit-button').click

    assert_selector '#timeline .bullet:not(.bullet--pending)', text: 'Fresh line from above'
    assert_pinned_to_bottom
    assert_equal 1, page.evaluate_script("document.querySelector('.timeline--scroller').pendingScrollCalls")
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

  test 'loading an older part of today keeps one append target at the end' do
    create_lines(PAGE + 5)
    visit bullets_path

    scroll_to_top
    wait_for_stable_bullet_count(minimum: PAGE + 5)

    assert_selector '#timeline_section_current_date', count: 1
    editor = find('#bullet_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('Newest line')
    find('#bullet_composer .composer--submit-button').click

    assert_selector '#timeline_section_current_date > turbo-frame.bullet', count: PAGE + 6
    assert_equal 'Newest line', page.evaluate_script(
      "document.querySelector('#timeline_section_current_date > turbo-frame.bullet:last-child').innerText.trim()"
    )
  end

  test 'older bullets are grouped under a heading for their span' do
    create_bullet!(@user, body: 'Today line', pops_on: Date.current)
    create_bullet!(@user, body: 'Old line', pops_on: Date.current - 10.days)

    visit bullets_path

    assert_selector '#timeline_section_current_date h2.pill', text: 'Today'
    assert_selector '#timeline_section_last-week h2.pill', text: 'Last week'
    assert_selector '#timeline_section_last-week .bullet', text: 'Old line'
  end

  private

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
