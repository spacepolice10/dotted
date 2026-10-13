# frozen_string_literal: true

class Timeline
  Section = Data.define(:id, :name)

  def initialize(user, filter: nil)
    @user = user
    @filter = filter || Bullet::Filter.from_params({}, user: user)
  end

  attr_reader :user, :filter

  def filtered
    filter.filtered(user.bullets)
  end

  def last_page
    filtered.preload(:collection).last_page
  end

  def prev_page(bullet)
    filtered.preload(:collection).prev_page(bullet)
  end

  # Every active bullet due on one day, oldest first. A single day is a bounded
  # rail, so `bullets#show` renders it whole instead of windowing around a
  # focal row.
  def on(date)
    filtered.preload(:collection).by_date.where(pops_on: date)
  end

  def section_of(date)
    self.class.section_of(date)
  end

  def self.section_of(date)
    date = date.to_date
    days_span = (Date.current - date).to_i

    case days_span
    when ...0    then Section.new(date.iso8601, date.strftime('%A, %b %-d'))
    when 0       then Section.new('current_date', 'Today')
    when 1       then Section.new('yesterday', 'Yesterday')
    when 2..6    then Section.new('this-week', 'This week')
    when 7..13   then Section.new('last-week', 'Last week')
    when 14..30  then Section.new('last-month', 'Last month')
    when 31..90  then Section.new('last-3-months', 'Last 3 months')
    when 91..365 then Section.new('last-year', 'Last year')
    else              Section.new("year-#{date.year}", date.year.to_s)
    end
  end
end
