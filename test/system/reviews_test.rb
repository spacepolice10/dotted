# frozen_string_literal: true

require 'application_system_test_case'

class ReviewsTest < ApplicationSystemTestCase
  test 'review entry opens a usable screen on mobile' do
    user = users(:one)
    create_bullet!(user, body: 'A little space to think')
    sign_in_as(user)
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride',
                                    width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    visit bullets_path
    click_link 'Review bullets'
    assert_selector '.review--card'
    assert_button 'Postpone'
    assert_button 'Complete'
    assert page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')
  end

  test 'selected bullets can be reviewed and completed one at a time' do
    user = users(:one)
    first = create_bullet!(user, body: 'Review this first')
    second = create_bullet!(user, body: 'Review this second')
    sign_in_as(user)
    visit bullets_path
    find("label[for='select_checkbox_bullet_#{first.id}']", match: :first).click
    find("label[for='select_checkbox_bullet_#{second.id}']", match: :first).click
    within '.bullet-menu--actions' do
      click_button 'Review', exact: true
    end
    assert_selector '.review--card', text: 'Review this first'
    assert_no_selector '.review--card', text: 'Review this second'
    click_button 'Complete', exact: true
    assert_selector '.review--card', text: 'Review this second'
    click_button 'Complete', exact: true
    assert_text 'All reviewed'
    assert first.reload.done?
    assert second.reload.done?
  end
end
