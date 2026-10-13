# frozen_string_literal: true

require 'test_helper'

module Timelines
  class BulletsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
    end

    test 'before returns the older page wrapped in its sections' do
      old = create_bullet!(@user, body: 'Old row', pops_on: Date.current - 20)
      cursor = create_bullet!(@user, body: 'Cursor row')

      get bullets_path(before: cursor.id)

      assert_response :success
      assert_select 'div#timeline_section_last-month .bullet', text: /Old row/
      assert_no_match 'Cursor row', response.body
      assert_equal old.id, @user.bullets.find_by!(pops_on: Date.current - 20).id
    end

    test 'before repeats the boundary section so the client can merge it' do
      earlier = create_bullet!(@user, body: 'Earlier today', created_at: 2.hours.ago)
      cursor = create_bullet!(@user, body: 'Later today', created_at: 1.hour.ago)

      get bullets_path(before: cursor.id)

      assert_response :success
      assert_select 'div#timeline_section_current_date .bullet', text: /#{earlier.name}/
    end

    test 'before omits an empty today section so pagination cannot duplicate the append target' do
      create_bullet!(@user, body: 'Old row', pops_on: Date.current - 20)
      cursor = create_bullet!(@user, body: 'Cursor row')

      get bullets_path(before: cursor.id)

      assert_response :success
      assert_select 'div#timeline_section_current_date', count: 0
    end

    test 'before returns no content when nothing older exists' do
      cursor = create_bullet!(@user, body: 'Only row')

      get bullets_path(before: cursor.id)

      assert_response :no_content
    end

    test 'before returns no content for an unknown cursor' do
      get bullets_path(before: 0)

      assert_response :no_content
    end

    test 'before ignores another users bullets' do
      foreign = create_bullet!(users(:two), body: 'Theirs')

      get bullets_path(before: foreign.id)

      assert_response :no_content
    end

    test 'before includes tagged bullets' do
      create_bullet!(@user, body: 'Filed row', pops_on: Date.current - 3, collection: create_collection!(@user, name: 'Work'))
      cursor = create_bullet!(@user, body: 'Cursor row')

      get bullets_path(before: cursor.id)

      assert_response :success
      assert_select '.bullet', text: /Filed row/
    end

    test 'before preserves collection filter' do
      collection = create_collection!(@user, name: 'Work')
      create_bullet!(@user, body: 'Tagged old', pops_on: Date.current - 3, collection: collection)
      create_bullet!(@user, body: 'Plain old', pops_on: Date.current - 3)
      cursor = create_bullet!(@user, body: 'Cursor row', collection: collection)

      get bullets_path(before: cursor.id, collection: collection.name)

      assert_response :success
      assert_select '.bullet', text: /Tagged old/
      assert_no_match 'Plain old', response.body
    end

    test 'before with completed returns older bullets in date sections' do
      old_done = create_bullet!(@user, body: 'Old done', pops_on: Date.current - 3)
      old_done.complete!
      cursor = create_bullet!(@user, body: 'Cursor done')
      cursor.complete!
      create_bullet!(@user, body: 'Not done')

      get bullets_path(before: cursor.id, completed: true)

      assert_response :success
      assert_select '#timeline_section_this-week .bullet', text: /Old done/
      assert_no_match 'Cursor done', response.body
      assert_no_match 'Not done', response.body
    end
  end
end
