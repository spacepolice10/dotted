# frozen_string_literal: true

module Bullet::Pageable
  extend ActiveSupport::Concern

  PAGE_SIZE = 50

  included do
    scope :by_date, -> { order(pops_on: :asc, created_at: :asc, id: :asc) }
    scope :earlier_date_than, lambda { |bullet|
      where(
        'bullets.pops_on < :pops_on ' \
        'OR (bullets.pops_on = :pops_on AND bullets.created_at < :created_at) ' \
        'OR (bullets.pops_on = :pops_on AND bullets.created_at = :created_at AND bullets.id < :id)',
        pops_on: bullet.pops_on, created_at: bullet.created_at, id: bullet.id
      )
    }
  end

  class_methods do
    # Load at most one date at a time, newest bullets first in the feed but
    # returned in reading order. Older bullets on the date are explicit.
    def last_page(size: PAGE_SIZE)
      date = maximum(:pops_on)
      date ? where(pops_on: date).by_date.last(size) : []
    end

    def prev_page(bullet, size: PAGE_SIZE)
      where(pops_on: ...bullet.pops_on).last_page(size: size)
    end

    def previous_page?(bullet)
      bullet.present? && where(pops_on: ...bullet.pops_on).exists?
    end

    def more_on_date?(bullet)
      where(pops_on: bullet.pops_on).earlier_date_than(bullet).exists?
    end
  end
end
