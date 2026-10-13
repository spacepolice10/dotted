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

  test 'prev_page returns the batch just older than the cursor' do
    bullets = create_bullets(6)

    page = @user.bullets.prev_page(bullets[3], size: 2)

    assert_equal bullets[1..2].map(&:id), page.map(&:id)
  end

  test 'prev_page is empty once the oldest bullet is the cursor' do
    bullets = create_bullets(2)

    assert_empty @user.bullets.prev_page(bullets.first)
  end

  test 'prev_page breaks created_at ties on id' do
    timestamp = 2.hours.ago
    bullets = Array.new(3) do |index|
      create_bullet!(@user, body: "Tied #{index}", created_at: timestamp)
    end

    page = @user.bullets.prev_page(bullets.last)

    assert_equal bullets.first(2).map(&:id), page.map(&:id)
  end

  test 'last_page reads by day before creation time' do
    late_today = create_bullet!(@user, body: 'Late today', pops_on: Date.current, created_at: 1.minute.ago)
    early_yesterday = create_bullet!(@user, body: 'Early yesterday', pops_on: Date.current - 1, created_at: 1.minute.ago)
    old_created_today = create_bullet!(@user, body: 'Moved to yesterday', pops_on: Date.current - 1, created_at: 2.hours.ago)

    ids = @user.bullets.last_page.map(&:id)

    assert_equal [old_created_today, early_yesterday, late_today].map(&:id), ids
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
