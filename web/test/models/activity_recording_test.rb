# frozen_string_literal: true

require 'test_helper'

class ActivityRecordingTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'postpone records rescheduled with the old and new day' do
    bullet = create_bullet!(@user, body: 'Later', pops_on: Date.current)

    assert_difference -> { Activity.count }, 1 do
      bullet.postpone!(pops_on: Date.current + 3)
    end

    activity = Activity.order(:created_at).last
    assert_equal 'rescheduled', activity.action
    assert_equal Date.current, activity.from_date
    assert_equal Date.current + 3, activity.to_date
  end

  test 'complete and collect do not record activity' do
    collection = create_collection!(@user, name: 'Inbox')
    bullet = create_bullet!(@user, body: 'Quiet')

    assert_no_difference -> { Activity.count } do
      bullet.complete!
      bullet.uncomplete!
      bullet.collect!(collection_id: collection.id)
    end
  end
end
