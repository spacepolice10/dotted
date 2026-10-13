# frozen_string_literal: true

require 'test_helper'

class Bullet::FilterTest < ActiveSupport::TestCase
  setup do
    travel_to Date.new(2026, 9, 30)
    @user = users(:one)
  end

  test 'default filter is due through today' do
    filter = Bullet::Filter.from_params({}, user: @user)

    assert filter.empty?
    assert_equal 'Daylog', filter.name

    due = create_bullet!(@user, body: 'Due', pops_on: Date.current)
    later = create_bullet!(@user, body: 'Later', pops_on: Date.current + 1)

    ids = filter.filtered(@user.bullets).pluck(:id)
    assert_includes ids, due.id
    assert_not_includes ids, later.id
  end

  test 'from filters upcoming bullets' do
    filter = Bullet::Filter.from_params({ from: (Date.current + 1).iso8601 }, user: @user)

    assert_equal 'Upcoming', filter.name

    due = create_bullet!(@user, body: 'Due', pops_on: Date.current)
    later = create_bullet!(@user, body: 'Later', pops_on: Date.current + 1)

    ids = filter.filtered(@user.bullets).pluck(:id)
    assert_not_includes ids, due.id
    assert_includes ids, later.id
  end

  test 'collection filter tags bullets' do
    collection = create_collection!(@user, name: 'Loose notes')
    tagged = create_bullet!(@user, body: 'Tagged', collection: collection, pops_on: Date.current)
    plain = create_bullet!(@user, body: 'Plain', pops_on: Date.current)

    filter = Bullet::Filter.from_params({ collection: 'loose notes' }, user: @user)
    ids = filter.filtered(@user.bullets).pluck(:id)

    assert_equal collection, filter.collection
    assert_includes ids, tagged.id
    assert_not_includes ids, plain.id
  end

  test 'unknown collection raises' do
    assert_raises(Bullet::Filter::Error) do
      Bullet::Filter.from_params({ collection: 'missing' }, user: @user)
    end
  end

  test 'completed flag selects done-only feed' do
    filter = Bullet::Filter.from_params({ completed: 'true' }, user: @user)

    assert filter.completed?
    assert_not filter.empty?
    assert_equal 'Completed', filter.name
    assert_equal({ completed: true }, filter.to_params)
  end

  test 'missing completed flag means undone feed' do
    filter = Bullet::Filter.from_params({}, user: @user)

    assert_not filter.completed?
    assert filter.empty?
  end

  test 'includes_date only when active date range covers it' do
    today = Date.current

    assert Bullet::Filter.from_params({}, user: @user).includes_date?(today)
    assert_not Bullet::Filter.from_params({ from: (today + 1).iso8601 }, user: @user).includes_date?(today)
    assert_not Bullet::Filter.from_params({ to: (today - 1).iso8601 }, user: @user).includes_date?(today)
    assert_not Bullet::Filter.from_params({ completed: true }, user: @user).includes_date?(today)
  end

  test 'completed flag ignores the default due-date window' do
    filter = Bullet::Filter.from_params({ completed: 'true' }, user: @user)
    future_done = create_bullet!(@user, body: 'Future done', pops_on: Date.current + 5)
    future_done.complete!
    active = create_bullet!(@user, body: 'Active')

    ids = filter.filtered(@user.bullets).map(&:id)
    assert_includes ids, future_done.id
    assert_not_includes ids, active.id
  end

  test 'inverted date range raises' do
    assert_raises(Bullet::Filter::Error) do
      Bullet::Filter.from_params({ from: '2026-10-02', to: '2026-09-01' }, user: @user)
    end
  end
end
