# frozen_string_literal: true

class CollectionItem < ApplicationRecord
  belongs_to :collection
  belongs_to :bullet

  validates :bullet_id, uniqueness: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :bullet_belongs_to_collection

  private

  def bullet_belongs_to_collection
    return if bullet.nil? || collection.nil?
    return if bullet.collection_id == collection.id && bullet.user_id == collection.user_id

    errors.add(:bullet, 'must belong to this collection')
  end
end
