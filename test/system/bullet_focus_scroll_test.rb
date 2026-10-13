# frozen_string_literal: true

require 'application_system_test_case'

class BulletFocusScrollSystemTest < ApplicationSystemTestCase
  PAGE = Bullet::Pageable::PAGE_SIZE

  # scrollIntoView centers within the scrollport, which sits below the header.
  CENTER_TOLERANCE = 80

  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test 'the focal bullet opens centered in the scroller' do
    bullets = create_lines(70)
    focal = bullets[35]

    visit bullet_path(focal)

    assert_selector '#timeline .bullet', count: 70
    assert_within 'the focal bullet sits near the middle of the scroller', CENTER_TOLERANCE do
      focal_offset_from_scroller_center
    end
  end

  test 'a busy day keeps its first focal bullet in view' do
    focal = create_bullet!(@user, body: 'Focal', pops_on: Date.current - 3)
    60.times { |index| create_bullet!(@user, body: "Bulk #{index}", pops_on: Date.current - 3) }

    visit bullet_path(focal)

    assert_selector '#timeline .bullet', count: 61
    assert_focal_bullet_in_view
  end

  test 'a bullet near the start of the feed still opens in view' do
    bullets = create_lines(70)
    focal = bullets[2]

    visit bullet_path(focal)

    assert_selector "#bullet_#{focal.id}"
    assert_focal_bullet_in_view
  end

  test 'the focal bullet has a distinct background' do
    bullets = create_lines(30)
    focal = bullets[15]

    visit bullet_path(focal)

    assert_selector ".bullet--current[aria-current=true] #bullet_#{focal.id}"
    assert_selector "#bullet_#{bullets[0].id}:not(.bullet--current)"
    refute_equal focal_background, neighbour_background(bullets[0]),
                 'expected the focal bullet to stand out from its neighbours'
  end

  private

  def create_lines(count)
    Array.new(count) do |index|
      create_bullet!(@user, body: "Line #{index}", created_at: (count - index).minutes.ago)
    end
  end

  # Positive when the focal row sits below the middle of the viewport.
  def focal_offset_from_scroller_center
    page.evaluate_script(<<~JS)
      (() => {
        const row = document.querySelector('.timeline--scroller .bullet--current')
        if (!row) return Number.NaN
        const box = row.getBoundingClientRect()
        const scroller = document.querySelector('.timeline--scroller').getBoundingClientRect()
        return (box.top + box.height / 2) - (scroller.top + scroller.height / 2)
      })()
    JS
  end

  def assert_focal_bullet_in_view
    visible = page.evaluate_script(<<~JS)
      (() => {
        const row = document.querySelector('.timeline--scroller .bullet--current').getBoundingClientRect()
        const scroller = document.querySelector('.timeline--scroller').getBoundingClientRect()
        return row.top >= scroller.top && row.bottom <= scroller.bottom
      })()
    JS
    assert visible, 'expected the focal bullet to be visible in the scroller'
  end

  def focal_background
    background_of('.timeline--scroller .bullet--current .bullet--body')
  end

  def neighbour_background(bullet)
    background_of("#bullet_#{bullet.id} .bullet--body")
  end

  def background_of(selector)
    page.evaluate_script(
      "getComputedStyle(document.querySelector('#{selector}')).backgroundColor"
    )
  end

  def assert_within(message, tolerance)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    offset = focal_offset_from_scroller_center

    while offset.abs > tolerance && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      sleep 0.05
      offset = focal_offset_from_scroller_center
    end

    assert_operator offset.abs, :<=, tolerance, "#{message} (offset was #{offset})"
  end
end
