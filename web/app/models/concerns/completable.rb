# frozen_string_literal: true

module Completable
  extend ActiveSupport::Concern

  RETENTION_DAYS = 30

  included do
    scope :completed, -> { where.not(completed_at: nil) }
    scope :uncompleted, -> { where(completed_at: nil) }
    scope :expired_completed, -> { completed.where(completed_at: ...RETENTION_DAYS.days.ago) }
  end

  def completed?
    completed_at.present?
  end

  def complete!
    return if completed?

    now = Time.current
    update!(completed_at: now, reviewed_at: now)
    forget_search_selections!
  end

  def uncomplete!
    return unless completed?

    update!(completed_at: nil, reviewed_at: nil)
  end
end
