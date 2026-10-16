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
    # Fetch a bounded number of bullets across dates, returned in reading order.
    def last_page(size: PAGE_SIZE)
      by_date.last(size)
    end

    def prev_page(bullet, size: PAGE_SIZE)
      earlier_date_than(bullet).last_page(size: size)
    end

    def previous_page?(bullet)
      bullet.present? && earlier_date_than(bullet).exists?
    end

    def more_on_date?(bullet)
      where(pops_on: bullet.pops_on).earlier_date_than(bullet).exists?
    end
  end
end
