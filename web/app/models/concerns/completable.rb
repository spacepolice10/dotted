# frozen_string_literal: true

module Completable
  extend ActiveSupport::Concern

  RETENTION_DAYS = 30

  included do
    scope :done, -> { where.not(done_at: nil) }
    scope :not_done, -> { where(done_at: nil) }
    scope :expired_done, -> { done.where(done_at: ...RETENTION_DAYS.days.ago) }
  end

  def done?
    done_at.present?
  end

  def complete!
    return if done?

    update!(done_at: Time.current)
    forget_search_selections!
  end

  def uncomplete!
    return unless done?

    update!(done_at: nil)
  end
end
