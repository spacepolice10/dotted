# frozen_string_literal: true

# Ordered steps attached to one bullet.
class Checklist < ApplicationRecord
  belongs_to :bullet
  has_many :items, -> { order(:position, :id) }, class_name: 'ChecklistItem',
           dependent: :destroy, inverse_of: :checklist

  accepts_nested_attributes_for :items, allow_destroy: true, reject_if: :reject_blank_item?

  validates :bullet_id, uniqueness: true
  validate :items_present

  private

  def reject_blank_item?(attributes)
    attributes['id'].blank? && attributes['text'].blank?
  end

  def items_present
    errors.add(:items, 'must include at least one item') if items.reject(&:marked_for_destruction?).empty?
  end
end
