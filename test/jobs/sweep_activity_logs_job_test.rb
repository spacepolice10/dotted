# frozen_string_literal: true

require 'test_helper'

class SweepActivityLogsJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @bullet = create_bullet!(@user, body: 'Task')
  end

  test 'perform sweeps expired activities' do
    stale = @bullet.record_activity!(
      'rescheduled',
      metadata: { 'from_pops_on' => Date.current.iso8601, 'to_pops_on' => (Date.current + 1).iso8601 }
    )
    stale.update_column(:created_at, (Activity::RETENTION_DAYS + 1).days.ago)

    assert_difference -> { Activity.count }, -1 do
      SweepActivityLogsJob.perform_now
    end
  end
end
