# frozen_string_literal: true

require 'test_helper'

class TimelineTest < ActiveSupport::TestCase
  setup do
    travel_to Date.new(2026, 9, 30)
  end

  test 'each date has its own section' do
    assert_equal 'current_date', section(0).id
    assert_equal '2026-09-29', section(1).id
    assert_equal 'Yesterday', section(1).name
    assert_equal '2026-09-28', section(2).id
    assert_equal 'Monday, Sep 28', section(2).name
    assert_equal '2025-09-30', section(365).id
    assert_equal 'Tuesday, Sep 30, 2025', section(365).name
  end

  test 'a future date gets its own section' do
    section = Timeline.section_of(Date.current + 1)
    assert_equal (Date.current + 1).iso8601, section.id
  end

  test 'bullets are due, not upcoming, up to today' do
    user = users(:one)
    due = create_bullet!(user, body: 'Due', pops_on: Date.current)
    past = create_bullet!(user, body: 'Past', pops_on: Date.current - 20)
    later = create_bullet!(user, body: 'Later', pops_on: Date.current + 2)
    filed = create_bullet!(user, body: 'Filed', collection: create_collection!(user, name: 'work'))
    done = create_bullet!(user, body: 'Done')
    done.complete!

    timeline = Timeline.new(user)

    assert_equal [past, due, filed].sort_by(&:id), timeline.filtered.sort_by(&:id)
    assert_not_includes timeline.filtered, later
  end

  test 'on returns every bullet due on one date in reading order' do
    user = users(:one)
    date = Date.current - 3
    bullets = Array.new(4) do |index|
      create_bullet!(user, body: "Day #{index}", pops_on: date, created_at: (4 - index).minutes.ago)
    end

    assert_equal bullets.map(&:id), Timeline.new(user).on(date).map(&:id)
  end

  test 'on skips other dates, completed bullets, and upcoming ones' do
    user = users(:one)
    date = Date.current - 3
    due = create_bullet!(user, body: 'Due', pops_on: date)
    create_bullet!(user, body: 'Earlier date', pops_on: date - 1)
    create_bullet!(user, body: 'Later date', pops_on: date + 1)
    done = create_bullet!(user, body: 'Done', pops_on: date)
    done.complete!
    create_bullet!(user, body: 'Upcoming', pops_on: Date.current + 1)

    assert_equal [due.id], Timeline.new(user).on(date).map(&:id)
  end

  test 'on is empty for a date with no incomplete bullets' do
    user = users(:one)
    date = Date.current - 3
    done = create_bullet!(user, body: 'Done', pops_on: date)
    done.complete!

    assert_empty Timeline.new(user).on(date)
  end

  test 'last_page and prev_page walk back through the feed' do
    user = users(:one)
    bullets = Array.new(5) { |index| create_bullet!(user, body: "Day #{index}", pops_on: Date.current - (4 - index)) }
    timeline = Timeline.new(user)

    assert_equal bullets.map(&:id), timeline.filtered.last_page.map(&:id)
    assert_equal bullets.first(2).map(&:id), timeline.filtered.prev_page(bullets[2]).map(&:id)
  end

  test 'prev_page skips completed and upcoming bullets' do
    user = users(:one)
    bullets = Array.new(3) { |index| create_bullet!(user, body: "Day #{index}", pops_on: Date.current - (2 - index)) }
    done = create_bullet!(user, body: 'Done', pops_on: Date.current - 5)
    done.complete!
    create_bullet!(user, body: 'Upcoming', pops_on: Date.current + 1)
    timeline = Timeline.new(user)

    assert_equal [bullets.first.id], timeline.filtered.prev_page(bullets[1]).map(&:id)
    assert_empty timeline.filtered.prev_page(bullets.first)
    assert_not_includes timeline.filtered, done
  end

  test 'filtered excludes completed bullets' do
    user = users(:one)
    timeline = Timeline.new(user)
    bullet = create_bullet!(user, body: 'Done line')
    bullet.complete!
    assert_not_includes timeline.filtered, bullet
  end

  test 'completed filter uses the same date ordering and pagination' do
    user = users(:one)
    old_done = create_bullet!(user, body: 'Old done', pops_on: Date.current - 3).tap(&:complete!)
    fresh_done = create_bullet!(user, body: 'Fresh done').tap(&:complete!)
    fresh_done.update!(done_at: 10.days.ago)
    create_bullet!(user, body: 'Not done')
    timeline = Timeline.new(user, filter: Bullet::Filter.from_params({ completed: 'true' }, user: user))
    assert_equal [old_done.id, fresh_done.id], timeline.filtered.last_page.map(&:id)
    assert_equal [old_done.id], timeline.filtered.prev_page(fresh_done).map(&:id)
    assert_empty timeline.filtered.prev_page(old_done)
  end

  test 'completed pages do not overlap' do
    user = users(:one)
    bullets = Array.new(Bullet::Pageable::PAGE_SIZE + 5) do |index|
      create_bullet!(user, body: "Done #{index}",
                           created_at: (Bullet::Pageable::PAGE_SIZE + 5 - index).minutes.ago).tap(&:complete!)
    end
    timeline = Timeline.new(user, filter: Bullet::Filter.from_params({ completed: true }, user: user))

    newest_page = timeline.filtered.last_page

    assert_equal bullets.last(Bullet::Pageable::PAGE_SIZE).map(&:id), newest_page.map(&:id)
    assert timeline.filtered.more_on_date?(newest_page.first)
    assert_equal bullets.first(5).map(&:id), timeline.filtered.prev_page(newest_page.first).map(&:id)
  end

  test 'automatic pages continue through a split date' do
    user = users(:one)
    older = create_bullet!(user, body: 'Earlier date', pops_on: Date.current - 3)
    today = Array.new(Bullet::Pageable::PAGE_SIZE + 5) do |index|
      create_bullet!(user, body: "Today #{index}", created_at: (Bullet::Pageable::PAGE_SIZE + 5 - index).minutes.ago)
    end
    timeline = Timeline.new(user)

    first = timeline.filtered.last_page
    second = timeline.filtered.prev_page(first.first)

    assert_equal today.last(Bullet::Pageable::PAGE_SIZE).map(&:id), first.map(&:id)
    assert timeline.filtered.more_on_date?(first.first)
    assert_equal [older.id] + today.first(5).map(&:id), second.map(&:id)
    assert_not timeline.filtered.previous_page?(second.first)
  end

  private

  def section(age)
    Timeline.section_of(Date.current - age)
  end
end
