# frozen_string_literal: true

require 'test_helper'

class ReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @first = create_bullet!(@user, body: 'First review bullet')
    @second = create_bullet!(@user, body: 'Second review bullet')
    @ids = "#{@first.id},#{@second.id}"
  end

  test 'selection displays one bullet at a time' do
    get review_path, params: { bullet_ids: @ids }
    assert_response :success
    assert_select '.review--card', count: 1
    assert_select '.review--card', text: /First review bullet/
    assert_select '.review--card', text: /Second review bullet/, count: 0
    assert_select '.review--progress', text: '2 bullets left to review'
  end

  test 'review uses the same collection and status chips as a bullet' do
    collection = create_collection!(@user, name: 'Review topics')
    @first.update!(collection: collection, last_postponed_at: Time.current, postponements_number: 1)

    get review_path, params: { bullet_ids: @ids }

    assert_select '.review--card .bullet--metadata .bullet--collection', text: collection.name
    assert_select '.review--card .bullet--metadata .bullet--status--postponed', text: 'Postponed 1 time'
    assert_select '.review--metadata', count: 0
  end

  test 'complete advances to the next bullet' do
    patch review_path, params: { bullet_ids: @ids, decision: 'complete' }
    assert @first.reload.completed?
    assert_not @second.reload.completed?
    follow_redirect!
    assert_select '.review--card', text: /Second review bullet/
  end

  test 'postpone persists date and advances' do
    patch review_path, params: { bullet_ids: @ids, decision: 'postpone', pops_on: Date.tomorrow.iso8601 }
    assert_equal Date.tomorrow, @first.reload.pops_on
    follow_redirect!
    assert_select '.review--card', text: /Second review bullet/
  end

  test 'save uses an owned collection and advances' do
    collection = create_collection!(@user, name: 'review destination')
    patch review_path, params: { bullet_ids: @ids, decision: 'collect', collection_id: collection.id }
    assert_equal collection, @first.reload.collection
    follow_redirect!
    assert_select '.review--card', text: /Second review bullet/
  end

  test 'invalid date keeps current bullet' do
    patch review_path, params: { bullet_ids: @ids, decision: 'postpone', pops_on: 'invalid' }
    assert_response :unprocessable_entity
    assert_select '[role=alert]'
    assert_select '.review--card', text: /First review bullet/
  end

  test 'foreign bullets cannot be viewed or changed' do
    foreign = create_bullet!(users(:two), body: 'Private')
    get review_path, params: { bullet_ids: "#{@first.id},#{foreign.id}" }
    assert_response :not_found
    patch review_path, params: { bullet_ids: foreign.id, decision: 'complete' }
    assert_response :not_found
    assert_not foreign.reload.completed?
  end

  test 'foreign collections cannot be used' do
    collection = create_collection!(users(:two), name: 'private review')
    patch review_path, params: { bullet_ids: @ids, decision: 'collect', collection_id: collection.id }
    assert_response :not_found
    assert_nil @first.reload.collection
  end

  test 'last action shows completion without restarting the queue' do
    patch review_path, params: { bullet_ids: @first.id, decision: 'complete' }
    follow_redirect!
    assert_select '.review--card', count: 0
    assert_match 'All reviewed', response.body
  end

  test 'default review excludes future and completed bullets' do
    future = create_bullet!(@user, body: 'Future', pops_on: Date.tomorrow)
    @first.complete!
    get review_path
    assert_response :success
    field = css_select('input[name=bullet_ids]').first
    ids = field['value'].split(',').map(&:to_i)
    assert_includes ids, @second.id
    assert_not_includes ids, @first.id
    assert_not_includes ids, future.id
  end
end
