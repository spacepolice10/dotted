# frozen_string_literal: true

require 'test_helper'

class SearchResultBodyTest < ActiveSupport::TestCase
  test 'a bullet renders its rich body so marks land inside formatting tags' do
    bullet = Bullet.new(body: '<p>Buy <strong>milk</strong> today</p>')

    assert_includes bullet.search_result_body, '<strong>milk</strong>'
  end

  test 'a bullet falls back to its filename when it has no body' do
    bullet = Bullet.new
    bullet.filename = 'receipt.pdf'

    assert_equal 'receipt.pdf', bullet.search_result_body
  end

  test 'a bullet with neither body nor filename still renders something' do
    assert_equal 'Untitled', Bullet.new.search_result_body
  end

  test 'a bullet body never collapses to its first line' do
    bullet = Bullet.new(body: '<p>Buy milk</p><p>and bread</p>')

    assert_includes bullet.search_result_body, 'and bread'
  end

  # Collection names are normalized to downcase on assignment, so results show
  # them the same way collections#index does.
  test 'a collection renders its name and description' do
    collection = Collection.new(name: 'Groceries', description: 'Weekly shop')

    assert_equal 'groceries — Weekly shop', collection.search_result_body
  end

  test 'a collection without a description renders only its name' do
    assert_equal 'groceries', Collection.new(name: 'Groceries').search_result_body
  end

  test 'every searchable exposes a type label' do
    assert_equal 'Bullet', Bullet.new.search_result_type
    assert_equal 'Collection', Collection.new.search_result_type
  end

  test 'every searchable exposes a result icon' do
    assert_equal 'circle', Bullet.new.search_result_icon
    assert_equal 'hash', Collection.new.search_result_icon
  end
end
