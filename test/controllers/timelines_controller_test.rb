# frozen_string_literal: true

require 'test_helper'

class TimelinesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'root is the daylog' do
    get root_path

    assert_response :success
    assert_select '#timeline.timeline--scroller[data-controller~="timeline-scroll"]'
  end

  test 'index mounts a hidden today section for the composer' do
    get bullets_path

    assert_response :success
    assert_select '#timeline_section_current_date'
    assert_select '#composer_dock input[name="bullet[file]"][type="file"]'
    assert_select '#timeline_composer_dock input[name="bullet[bulletable_type]"]', count: 0
    assert_select '.timeline--load-more-trigger', count: 0
  end

  test 'index groups bullets into sections by age' do
    create_bullet!(@user, body: 'Today line')
    create_bullet!(@user, body: 'Yesterday line', pops_on: Date.current - 1)
    create_bullet!(@user, body: 'Ancient line', pops_on: Date.current - 20)

    get bullets_path

    assert_select '#timeline_section_current_date .bullet', text: /Today line/
    assert_select '#timeline_section_yesterday .bullet', text: /Yesterday line/
    assert_select '#timeline_section_last-month .bullet', text: /Ancient line/
    assert_select '#timeline_section_last-month h2.pill', text: 'Last month'
  end

  test 'sections read oldest first' do
    create_bullet!(@user, body: 'Ancient line', pops_on: Date.current - 20)
    create_bullet!(@user, body: 'Today line')

    get bullets_path

    assert_operator response.body.index('Ancient line'), :<, response.body.index('Today line')
  end

  test 'index hides upcoming and completed bullets and keeps tagged ones' do
    create_bullet!(@user, body: 'Future line', pops_on: Date.current + 3)
    create_bullet!(@user, body: 'Filed line', collection: create_collection!(@user, name: 'Work'))
    create_bullet!(@user, body: 'Gone line').complete!

    get bullets_path

    assert_no_match 'Future line', response.body
    assert_match 'Filed line', response.body
    assert_no_match 'Gone line', response.body
  end

  test 'a full page shows the older trigger' do
    Array.new(Bullet::Pageable::PAGE_SIZE + 1) { |i| create_bullet!(@user, body: "Line #{i}", created_at: (100 - i).minutes.ago) }

    get bullets_path

    assert_select '.timeline--load-more-trigger'
    assert_select '#timeline .bullet', count: Bullet::Pageable::PAGE_SIZE
  end

  test 'requires authentication' do
    sign_out

    get bullets_path

    assert_redirected_to new_authentication_path
  end
end
