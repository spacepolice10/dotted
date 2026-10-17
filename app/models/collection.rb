# frozen_string_literal: true

class Collection < ApplicationRecord
  include Colourable, Iconable, Collection::Searchable, Collection::NameMatching

  belongs_to :user
  has_many :bullets, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :description, length: { maximum: 280 }, allow_blank: true

  normalizes :name, with: ->(name) { name.strip.downcase }

  scope :favorites, -> { where(favorite: true) }

  def save_and_collect!(bullets: Bullet.none)
    transaction do
      save!
      bullets.lock.find_each { |bullet| bullet.collect!(collection_id: id) }
    end
    self
  end

  def colour_variable = Colourable.colour_variable_of(colour)
end
