# frozen_string_literal: true

require "test_helper"

class CleanSoftDeletedRecordsJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
  end

  test "destroys expired done bullets" do
    bullet = create_bullet!(@user, body: "Old news")
    expire!(bullet)

    assert_difference -> { Bullet.count }, -1 do
      CleanSoftDeletedRecordsJob.perform_now
    end
  end

  test "keeps recently completed bullets" do
    bullet = create_bullet!(@user, body: "Fresh done")
    bullet.complete!

    assert_no_difference -> { Bullet.count } do
      CleanSoftDeletedRecordsJob.perform_now
    end

    assert bullet.reload.done?
  end

  test "purges old unattached blobs" do
    blob = create_blob!(filename: "orphan.png", content_type: "image/png")
    blob.update!(created_at: 3.days.ago)

    assert_enqueued_with(job: ActiveStorage::PurgeJob) do
      CleanSoftDeletedRecordsJob.perform_now
    end
  end

  test "keeps recent unattached blobs" do
    create_blob!(filename: "fresh.png", content_type: "image/png")

    assert_no_enqueued_jobs(only: ActiveStorage::PurgeJob) do
      CleanSoftDeletedRecordsJob.perform_now
    end
  end

  private

  def expire!(record)
    record.complete!
    record.update!(done_at: (Completable::RETENTION_DAYS + 1).days.ago)
  end
end
