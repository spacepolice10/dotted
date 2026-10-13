# frozen_string_literal: true

class SweepActivityLogsJob < ApplicationJob
  def perform
    Activity.where(created_at: ...Activity::RETENTION_DAYS.days.ago).delete_all
  end
end
