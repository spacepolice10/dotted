# frozen_string_literal: true

require 'application_system_test_case'

class BulletDetailSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test 'a detail page shows only the requested bullet from a busy feed' do
    bullets = create_lines(70)
    focal = bullets[35]

    visit bullet_path(focal)

    assert_selector 'main.bullet-page .bullet', count: 1
    assert_selector ".bullet--current[aria-current=true] #bullet_#{focal.id}"
    assert_no_selector '.timeline--scroller'
    assert_no_selector '.composer'
    assert_focal_bullet_in_view
  end

  test 'the first bullet of a busy day opens directly' do
    focal = create_bullet!(@user, body: 'Focal', pops_on: Date.current - 3)
    60.times { |index| create_bullet!(@user, body: "Bulk #{index}", pops_on: Date.current - 3) }

    visit bullet_path(focal)

    assert_selector 'main.bullet-page .bullet', count: 1
    assert_selector "#bullet_#{focal.id}", text: 'Focal'
    assert_focal_bullet_in_view
  end

  test 'an older bullet stays visible at narrow widths with enlarged text' do
    focal = create_lines(70)[2]
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: 320, height: 844, deviceScaleFactor: 1, mobile: true)

    visit bullet_path(focal)
    page.execute_script("document.documentElement.style.fontSize = '200%'")

    assert_selector "#bullet_#{focal.id}"
    assert_focal_bullet_in_view
    assert_operator page.evaluate_script('document.documentElement.scrollWidth'), :<=,
                    page.evaluate_script('document.documentElement.clientWidth')
  end

  test 'the current bullet keeps its visible accent marker' do
    focal = create_lines(2).last
    visit bullet_path(focal)

    assert_selector ".bullet--current[aria-current=true] #bullet_#{focal.id}"
    marker = page.evaluate_script(<<~JS)
      (() => {
        const style = getComputedStyle(document.querySelector('.bullet--current'), '::before');
        return {content: style.content, width: parseFloat(style.width), background: style.backgroundColor};
      })()
    JS
    refute_equal 'none', marker['content']
    assert_operator marker['width'], :>, 0
    refute_equal 'rgba(0, 0, 0, 0)', marker['background']
  end

  private

  def create_lines(count)
    Array.new(count) do |index|
      create_bullet!(@user, body: "Line #{index}", created_at: (count - index).minutes.ago)
    end
  end

  def assert_focal_bullet_in_view
    visible = page.evaluate_script(<<~JS)
      (() => {
        const row = document.querySelector('.bullet--current').getBoundingClientRect();
        const tabbar = document.querySelector('.tabbar--navigation, .tabbar--back');
        const bottom = tabbar ? Math.min(innerHeight, tabbar.getBoundingClientRect().top) : innerHeight;
        return row.top >= 0 && row.bottom <= bottom;
      })()
    JS
    assert visible, 'expected the requested bullet to be visible above navigation'
  end
end
