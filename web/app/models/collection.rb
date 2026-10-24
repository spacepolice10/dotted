# frozen_string_literal: true

class Collection < ApplicationRecord
  include Colourable, Iconable, Collection::Searchable, Collection::NameMatching

  belongs_to :user
  has_many :bullets, dependent: :nullify
  has_many :collection_items, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :description, length: { maximum: 280 }, allow_blank: true

  normalizes :name, with: ->(name) { name.strip.downcase }

  scope :favorites, -> { where(favorite: true) }

  def save_and_collect!(bullets: Bullet.none)
    transaction do
      save!
      bullets.lock.find_each do |bullet|
        bullet.collect!(collection_id: id)
      end
    end
    self
  end

  def colour_variable = Colourable.colour_variable_of(colour)

  def unsorted_bullets
    bullets.uncompleted.where.not(id: collection_items.select(:bullet_id))
           .preload(:collection, note: :rich_text_content)
           .order(created_at: :desc, id: :desc)
  end

  def parked_items
    collection_items.joins(:bullet).merge(Bullet.uncompleted)
                    .includes(bullet: [:collection, { note: :rich_text_content }])
                    .order(:position, :id)
  end

  def move_bullet!(bullet_id:, lane:, before_id: nil)
    raise ArgumentError, 'Unknown lane' unless lane.in?(%w[unsorted parked])

    with_lock do
      bullet = bullets.find(bullet_id)
      items = collection_items.order(:position, :id).to_a
      moving = items.find { |item| item.bullet_id == bullet.id }

      if lane == 'unsorted'
        moving&.destroy!
      else
        moving ||= collection_items.build(bullet: bullet)
        items.delete(moving)
        index = before_id.present? ? items.index { |item| item.bullet_id == before_id.to_i } : 0
        raise ArgumentError, 'Invalid position' if index.nil?

        items.insert(index, moving)
        items.each_with_index do |item, position|
          item.update!(position: position) if item.new_record? || item.position != position
        end
      end
    end
  end

  def move_bullets!(bullet_ids:, lane:)
    transaction do
      bullet_ids.reverse_each { |bullet_id| move_bullet!(bullet_id: bullet_id, lane: lane) }
    end
  end
end
