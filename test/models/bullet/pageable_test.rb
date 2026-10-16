# frozen_string_literal: true

require 'test_helper'

class Bullet::PageableTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'last_page returns the newest bullets in reading order' do
    bullets = create_bullets(5)

    page = @user.bullets.last_page(size: 3)

    assert_equal bullets.last(3).map(&:id), page.map(&:id)
  end

  test 'last_page returns everything when the feed is shorter than a page' do
    bullets = create_bullets(2)

    assert_equal bullets.map(&:id), @user.bullets.last_page(size: 3).map(&:id)
  end

  test 'prev_page moves to the previous date' do
    older = create_bullet!(@user, body: 'Older', pops_on: Date.current - 1)
    cursor = create_bullet!(@user, body: 'Cursor')

    assert_equal [older.id], @user.bullets.prev_page(cursor).map(&:id)
  end

  test 'prev_page is empty once the oldest bullet is the cursor' do
    bullets = create_bullets(2)

    assert_empty @user.bullets.prev_page(bullets.first)
  end

  test 'more_on_date handles created_at ties using id' do
    timestamp = 2.hours.ago
    bullets = Array.new(3) do |index|
      create_bullet!(@user, body: "Tied #{index}", created_at: timestamp)
    end

    assert @user.bullets.more_on_date?(bullets.last)
    assert_not @user.bullets.more_on_date?(bullets.first)
  end

  test 'last_page reads by day before creation time' do
    late_today = create_bullet!(@user, body: 'Late today', pops_on: Date.current, created_at: 1.minute.ago)
    early_yesterday = create_bullet!(@user, body: 'Early yesterday', pops_on: Date.current - 1,
                                            created_at: 1.minute.ago)
    old_created_today = create_bullet!(@user, body: 'Moved to yesterday', pops_on: Date.current - 1,
                                              created_at: 2.hours.ago)

    ids = @user.bullets.last_page.map(&:id)

    assert_equal [late_today.id], ids
    assert_equal [old_created_today, early_yesterday].map(&:id), @user.bullets.prev_page(late_today).map(&:id)
  end

  test 'a date with more than one page exposes a show all link' do
    bullets = create_bullets(Bullet::Pageable::PAGE_SIZE + 5)
    first = @user.bullets.last_page

    assert_equal bullets.last(Bullet::Pageable::PAGE_SIZE).map(&:id), first.map(&:id)
    assert @user.bullets.more_on_date?(first.first)
    assert_not @user.bullets.previous_page?(first.first)
  end

  test 'prev_page returns bullets from earlier days first' do
    older = create_bullet!(@user, body: 'Older', pops_on: Date.current - 3)
    newer = create_bullet!(@user, body: 'Newer', pops_on: Date.current - 1)

    assert_equal [older.id], @user.bullets.prev_page(newer).map(&:id)
    assert_empty @user.bullets.prev_page(older)
  end

  private

  def create_bullets(count)
    Array.new(count) do |index|
      create_bullet!(@user, body: "Line #{index}", created_at: (count - index).minutes.ago)
    end
  end
end
