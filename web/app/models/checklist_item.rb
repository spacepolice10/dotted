# frozen_string_literal: true

# One checkable step in a bullet's checklist.
class ChecklistItem < ApplicationRecord
  belongs_to :checklist, inverse_of: :items

  normalizes :text, with: lambda(&:strip)

  validates :text, presence: true, length: { maximum: 500 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def completed? = completed_at.present?

  def set_completed!(completed:)
    update!(completed_at: completed ? (completed_at || Time.current) : nil)
  end
end
