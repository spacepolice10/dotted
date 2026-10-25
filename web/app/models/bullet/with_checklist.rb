# frozen_string_literal: true

# Owns the optional checklist and applies editor changes atomically.
module Bullet::WithChecklist
  extend ActiveSupport::Concern

  included do
    has_one :checklist, dependent: :destroy
    scope :with_checklist, -> { joins(:checklist) }
  end

  def with_checklist? = checklist&.items&.any?

  def update_checklist(attributes, resurface: false)
    transaction do
      record = checklist || build_checklist
      record.assign_attributes(attributes)
      next false unless persist_checklist(record)

      resurface! if resurface
      true
    end
  end

  private

  def persist_checklist(record)
    return record.save if record.items.reject(&:marked_for_destruction?).any?

    unless record.persisted?
      record.errors.add(:items, 'must include at least one item')
      return false
    end

    record.destroy!
    association(:checklist).reset
    true
  end
end
