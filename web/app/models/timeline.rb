# frozen_string_literal: true

class Timeline
  Section = Data.define(:id, :name)

  def initialize(user, filter: nil)
    @user = user
    @filter = filter || Bullet::Filter.from_params({}, user: user)
  end

  attr_reader :user, :filter

  def filtered
    bullets = filter.completed? ? user.bullets.completed : user.bullets.not_done
    filter.filtered(bullets)
  end

  # The focused bullet page renders the whole date around its selected row.
  def on(date)
    filtered.preload(:collection).by_date.where(pops_on: date)
  end

  def dates_over_page_limit(dates)
    filtered.where(pops_on: dates).group(:pops_on)
            .having("COUNT(*) > ?", Bullet::Pageable::PAGE_SIZE).pluck(:pops_on)
  end

  def section_of(date)
    self.class.section_of(date)
  end

  def self.section_of(date)
    date = date.to_date
    return Section.new('current_date', 'Today') if date == Date.current

    name = date == Date.yesterday ? 'Yesterday' : date.strftime('%A, %b %-d')
    name = "#{name}, #{date.year}" if date.year != Date.current.year
    Section.new(date.iso8601, name)
  end
end
