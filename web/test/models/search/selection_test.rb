# frozen_string_literal: true

require 'test_helper'

class Search::SelectionTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @collection = create_collection!(@user, name: 'alpha')
  end

  test 'record! upserts the same target' do
    Search::Selection.record!(user: @user, searchable: @collection)

    travel 1.hour do
      Search::Selection.record!(user: @user, searchable: @collection)

      selection = @user.search_selections.sole
      assert_in_delta Time.current, selection.selected_at, 1.second
    end

    assert_equal 1, @user.search_selections.count
  end

  test 'record! keeps at most LIMIT selections per user' do
    collections = (Search::Selection::LIMIT + 1).times.map { |i| create_collection!(@user, name: "collection #{i}") }

    collections.each do |collection|
      Search::Selection.record!(user: @user, searchable: collection)
    end

    assert_equal Search::Selection::LIMIT, @user.search_selections.count
    assert_not_includes @user.search_selections.pluck(:searchable_id), collections.first.id
  end

  test 'in_menu returns recent selections up to LIMIT' do
    collections = (Search::Selection::LIMIT + 1).times.map { |i| create_collection!(@user, name: "menu collection #{i}") }

    collections.each do |collection|
      Search::Selection.record!(user: @user, searchable: collection)
    end

    selections = Search::Selection.in_menu(@user)

    assert_equal Search::Selection::LIMIT, selections.size
    assert_equal collections.last.id, selections.first.searchable_id
  end

  test 'in_menu skips selections whose searchable was deleted' do
    deleted = create_collection!(@user, name: 'gone')
    kept = create_collection!(@user, name: 'kept')

    Search::Selection.record!(user: @user, searchable: deleted)
    Search::Selection.record!(user: @user, searchable: kept)

    deleted.destroy!

    selections = Search::Selection.in_menu(@user)

    assert_equal 1, selections.size
    assert_equal kept, selections.first.searchable
  end

  test 'complete! removes bullet from recent selections' do
    bullet = create_bullet!(@user, body: 'Finish me')

    Search::Selection.record!(user: @user, searchable: bullet)

    bullet.complete!

    assert_empty Search::Selection.in_menu(@user)
  end

  test 'complete removes bullet from search index and uncomplete restores it' do
    bullet = create_bullet!(@user, body: 'Park me somewhere')

    assert Search::Record.exists?(searchable_type: 'Bullet', searchable_id: bullet.id)

    bullet.complete!

    assert_not Search::Record.exists?(searchable_type: 'Bullet', searchable_id: bullet.id)

    bullet.uncomplete!

    assert Search::Record.exists?(searchable_type: 'Bullet', searchable_id: bullet.id)
  end

  test 'in_menu returns selections with searchable loaded' do
    Search::Selection.record!(user: @user, searchable: @collection)

    selection = Search::Selection.in_menu(@user).sole

    assert_equal @collection, selection.searchable
  end
end
