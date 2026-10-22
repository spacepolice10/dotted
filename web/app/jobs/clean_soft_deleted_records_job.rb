# frozen_string_literal: true

class CleanSoftDeletedRecordsJob < ApplicationJob
  UNATTACHED_BLOB_RETENTION = 2.days

  def perform
    Bullet.expired_done.destroy_all
    purge_unattached_blobs
  end

  private

  def purge_unattached_blobs
    ActiveStorage::Blob.unattached.where(created_at: ..UNATTACHED_BLOB_RETENTION.ago).find_each(&:purge_later)
  end
end
