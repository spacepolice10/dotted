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
    click_link 'Review…'
    assert_selector '.review--card'
    assert_selector '.tabbar--back-link', text: 'Back'
    assert_no_selector '.review--close'
    assert_button 'Postpone'
    assert_button 'Complete'
    assert_operator find_button('Complete').rect.y, :>, find_button('Postpone').rect.y
    assert_operator find('.review--card').rect.height, :<, 300
    assert page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')
    find('.tabbar--back-link').click
    assert_current_path bullets_path
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
    assert_current_path review_path(bullet_ids: second.id.to_s)
    click_button 'Complete', exact: true
    assert_text 'All reviewed'
    assert first.reload.done?
    assert second.reload.done?
    page.go_back
    assert_current_path bullets_path
  end

  test 'postpone and tag use the bullet pickers and advance the review' do
    user = users(:one)
    first = create_bullet!(user, body: 'Schedule this')
    second = create_bullet!(user, body: 'Tag this')
    collection = create_collection!(user, name: 'Keep close')
    sign_in_as(user)

    visit bullets_path
    visit review_path(bullet_ids: "#{first.id},#{second.id}")
    click_button 'Postpone'
    assert_selector '#postpone_dialog[open]'
    within '#postpone_dialog' do
      find("button[name='pops_on'][value='#{Date.tomorrow.iso8601}']").click
    end
    assert_selector '.review--card', text: 'Tag this'
    assert_current_path review_path(bullet_ids: second.id.to_s)
    assert_equal Date.tomorrow, first.reload.pops_on

    click_button 'Tag'
    assert_selector '#collects_dialog[open]'
    within '#collects_dialog' do
      fill_in 'Search collections', with: collection.name
      click_button collection.name
    end
    assert_text 'All reviewed'
    assert_equal collection, second.reload.collection
    page.go_back
    assert_current_path bullets_path
  end
end
