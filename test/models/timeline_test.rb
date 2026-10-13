# frozen_string_literal: true

require 'test_helper'

class TimelineTest < ActiveSupport::TestCase
  setup do
    travel_to Date.new(2026, 9, 30)
  end

  test 'sections split recent days and then widen' do
    assert_equal 'current_date', section(0).id
    assert_equal 'yesterday', section(1).id
    assert_equal 'this-week', section(2).id
    assert_equal 'This week', section(2).name
    assert_equal 'this-week', section(6).id
    assert_equal 'last-week', section(7).id
    assert_equal 'last-week', section(13).id
    assert_equal 'last-month', section(14).id
    assert_equal 'last-month', section(30).id
    assert_equal 'last-3-months', section(31).id
    assert_equal 'last-3-months', section(90).id
    assert_equal 'last-year', section(91).id
    assert_equal 'last-year', section(365).id
    assert_equal 'year-2025', section(366).id
  end

  test 'a future day gets its own section' do
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

  test 'on returns every bullet due on one day in reading order' do
    user = users(:one)
    day = Date.current - 3
    bullets = Array.new(4) do |index|
      create_bullet!(user, body: "Day #{index}", pops_on: day, created_at: (4 - index).minutes.ago)
    end

    assert_equal bullets.map(&:id), Timeline.new(user).on(day).map(&:id)
  end

  test 'on skips other days, completed bullets, and upcoming ones' do
    user = users(:one)
    day = Date.current - 3
    due = create_bullet!(user, body: 'Due', pops_on: day)
    create_bullet!(user, body: 'Earlier day', pops_on: day - 1)
    create_bullet!(user, body: 'Later day', pops_on: day + 1)
    done = create_bullet!(user, body: 'Done', pops_on: day)
    done.complete!
    create_bullet!(user, body: 'Upcoming', pops_on: Date.current + 1)

    assert_equal [due.id], Timeline.new(user).on(day).map(&:id)
  end

  test 'on is empty for a day with no incomplete bullets' do
    user = users(:one)
    day = Date.current - 3
    done = create_bullet!(user, body: 'Done', pops_on: day)
    done.complete!

    assert_empty Timeline.new(user).on(day)
  end

  test 'last_page and prev_page walk back through the feed' do
    user = users(:one)
    bullets = Array.new(5) { |index| create_bullet!(user, body: "Day #{index}", pops_on: Date.current - (4 - index)) }
    timeline = Timeline.new(user)

    assert_equal bullets.map(&:id), timeline.last_page.map(&:id)
    assert_equal bullets.first(2).map(&:id), timeline.prev_page(bullets[2]).map(&:id)
  end

  test 'prev_page skips completed and upcoming bullets' do
    user = users(:one)
    bullets = Array.new(3) { |index| create_bullet!(user, body: "Day #{index}", pops_on: Date.current - (2 - index)) }
    done = create_bullet!(user, body: 'Done', pops_on: Date.current - 5)
    done.complete!
    create_bullet!(user, body: 'Upcoming', pops_on: Date.current + 1)
    timeline = Timeline.new(user)

    assert_equal [bullets.first.id], timeline.prev_page(bullets[1]).map(&:id)
    assert_empty timeline.prev_page(bullets.first)
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
    assert_equal [old_done.id, fresh_done.id], timeline.last_page.map(&:id)
    assert_equal [old_done.id], timeline.prev_page(fresh_done).map(&:id)
    assert_empty timeline.prev_page(old_done)
  end

  test 'completed pages do not overlap' do
    user = users(:one)
    bullets = Array.new(Bullet::Pageable::PAGE_SIZE + 5) do |index|
      create_bullet!(user, body: "Done #{index}", pops_on: Date.current - (Bullet::Pageable::PAGE_SIZE + 5 - index)).tap(&:complete!)
    end
    timeline = Timeline.new(user, filter: Bullet::Filter.from_params({ completed: true }, user: user))

    newest_page = timeline.last_page
    older_page = timeline.prev_page(newest_page.first)

    assert_equal bullets.last(Bullet::Pageable::PAGE_SIZE).map(&:id), newest_page.map(&:id)
    assert_equal bullets.first(5).map(&:id), older_page.map(&:id)
  end

  private

  def section(age)
    Timeline.section_of(Date.current - age)
  end
end
