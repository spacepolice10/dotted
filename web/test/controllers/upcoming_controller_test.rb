# frozen_string_literal: true

require 'test_helper'

class UpcomingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'from tomorrow lists future bullets soonest first' do
    later = create_bullet!(@user, body: 'Next month', pops_on: Date.current + 30)
    sooner = create_bullet!(@user, body: 'Tomorrow', pops_on: Date.current + 1)

    get bullets_path(from: Date.current + 1)

    assert_response :success
    assert_operator response.body.index(sooner.name), :<, response.body.index(later.name)
  end

  test 'from tomorrow leaves out todays bullets and completed ones' do
    create_bullet!(@user, body: 'On the timeline')
    tagged = create_bullet!(@user, body: 'Filed away', pops_on: Date.current + 2, collection: create_collection!(@user, name: 'Work'))
    create_bullet!(@user, body: 'Dropped', pops_on: Date.current + 2).complete!

    get bullets_path(from: Date.current + 1)

    assert_no_match 'On the timeline', response.body
    assert_match tagged.name, response.body
    assert_no_match 'Dropped', response.body
  end

  test 'from tomorrow does not list another users bullets' do
    create_bullet!(users(:two), body: 'Theirs', pops_on: Date.current + 2)

    get bullets_path(from: Date.current + 1)

    assert_no_match 'Theirs', response.body
  end

end
