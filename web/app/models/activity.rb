# frozen_string_literal: true

class Activity < ApplicationRecord
  ACTIONS = %w[rescheduled].freeze

  belongs_to :user
  belongs_to :subject, polymorphic: true, optional: true

  RETENTION_DAYS = 30

  validates :action, inclusion: { in: ACTIONS }
  validates :subject, presence: true

  def from_date
    return if metadata['from_pops_on'].blank?

    metadata['from_pops_on'].to_date
  end

  def to_date
    return if metadata['to_pops_on'].blank?

    metadata['to_pops_on'].to_date
  end
end
