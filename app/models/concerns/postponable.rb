# frozen_string_literal: true

module Postponable
  extend ActiveSupport::Concern

  def postpone!(pops_on:)
    raise ArgumentError, 'pops_on is required' if pops_on.blank?

    target = pops_on.to_date
    return if self.pops_on == target

    from = self.pops_on
    attributes = { pops_on: target }
    if from.present? && target > from
      attributes[:last_postponed_at] = Time.current
      attributes[:postponements_number] = postponements_number + 1
    end
    update!(attributes)
    record_activity!(
      'rescheduled',
      metadata: { 'from_pops_on' => from&.iso8601, 'to_pops_on' => target.iso8601 }
    )
  end
end
