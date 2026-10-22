# frozen_string_literal: true

require 'test_helper'

class PublishedControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'index lists published bullets for current user' do
    published = create_bullet!(@user, body: 'Public note')
    published.publish!
    create_bullet!(@user, body: 'Private task')

    get published_index_path

    assert_response :success
    assert_match 'Public note', response.body
    assert_no_match 'Private task', response.body
  end

  test 'show renders published bullet without authentication' do
    bullet = create_bullet!(@user, body: 'Shared content')
    bullet.publish!

    sign_out

    get published_path(bullet.public_code)

    assert_response :success
    assert_match 'Shared content', response.body
  end

  test 'show returns not found for unknown code' do
    get published_path('missing-code')

    assert_response :not_found
  end

  test 'show omits the private collection without querying it' do
    collection = @user.collections.create!(name: 'Private collection')
    bullet = create_bullet!(@user, body: 'Shared content', collection: collection)
    bullet.publish!
    code = bullet.public_code
    sign_out

    collection_queries = []
    subscriber = lambda do |event|
      sql = event.payload[:sql]
      collection_queries << sql if sql.match?(/\bFROM\s+"collections"/i)
    end
    ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') do
      get published_path(code)
    end

    assert_response :success
    assert_match 'Shared content', response.body
    assert_select '.bullet--collection', count: 0
    assert_no_match collection.name, response.body
    assert_empty collection_queries
    assert_equal collection.id, bullet.reload.collection_id
  end

  test 'show returns not found after unpublish' do
    bullet = create_bullet!(@user, body: 'Was public')
    bullet.publish!
    code = bullet.public_code
    bullet.unpublish!

    get published_path(code)

    assert_response :not_found
  end
end
