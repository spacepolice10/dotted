# frozen_string_literal: true

require 'test_helper'

module Collections
  class ItemsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @collection = create_collection!(@user, name: 'Reading')
      @first = create_bullet!(@user, body: 'First', collection: @collection, pops_on: Date.current - 5)
      @second = create_bullet!(@user, body: 'Second', collection: @collection, pops_on: Date.current + 5)
    end

    test 'parking and unpark leave dates unchanged and update only the collection board' do
      original_date = @first.pops_on

      patch collection_item_path(@collection, bullet_id: @first.id), params: { lane: 'parked' }, as: :turbo_stream

      assert_response :success
      assert_equal original_date, @first.reload.pops_on
      assert_equal [@first], @collection.parked_items.map(&:bullet)
      assert_not_includes @collection.unsorted_bullets, @first
      assert_select "turbo-stream[action=replace][target=#{dom_id(@collection, :board)}]"

      patch collection_item_path(@collection, bullet_id: @first.id), params: { lane: 'unsorted' }, as: :turbo_stream

      assert_response :success
      assert_empty @collection.collection_items
      assert_includes @collection.unsorted_bullets, @first
      assert_equal original_date, @first.reload.pops_on
    end

    test 'parked bullets can be reordered' do
      patch collection_item_path(@collection, bullet_id: @first.id), params: { lane: 'parked' }
      patch collection_item_path(@collection, bullet_id: @second.id), params: { lane: 'parked' }

      assert_equal [@second.id, @first.id], @collection.parked_items.map(&:bullet_id)

      patch collection_item_path(@collection, bullet_id: @first.id), params: { lane: 'parked', before_id: @second.id }

      assert_equal [@first.id, @second.id], @collection.parked_items.map(&:bullet_id)
      assert_equal [0, 1], @collection.parked_items.map(&:position)
    end

    test 'bulk lane movement keeps selected order and dates' do
      dates = [@first.pops_on, @second.pops_on]

      patch collection_move_items_path(@collection),
            params: { bullet_ids: "#{@first.id},#{@second.id}", lane: 'parked' }, as: :turbo_stream

      assert_response :success
      assert_equal [@first.id, @second.id], @collection.parked_items.map(&:bullet_id)
      assert_equal dates, [@first.reload.pops_on, @second.reload.pops_on]
      assert_select "turbo-stream[action=replace][target=#{dom_id(@collection, :board)}]"

      patch collection_move_items_path(@collection),
            params: { bullet_ids: "#{@first.id},#{@second.id}", lane: 'unsorted' }, as: :turbo_stream

      assert_response :success
      assert_empty @collection.collection_items.reload
    end

    test 'completed parked bullets disappear and return to parked when uncompleted' do
      @collection.move_bullet!(bullet_id: @first.id, lane: 'parked')
      @first.complete!

      get collection_path(@collection)
      assert_select ".collection-board #collection_item_#{dom_id(@first)}", count: 0

      @first.uncomplete!
      get collection_path(@collection)
      assert_select ".collection--lane[data-lane=parked] #collection_item_#{dom_id(@first)}", count: 1
    end

    test 'completed placement is retained for uncompletion, while foreign bullets cannot be moved' do
      @first.complete!
      foreign = create_bullet!(users(:two), body: 'Private')

      patch collection_item_path(@collection, bullet_id: @first.id), params: { lane: 'parked' }
      assert_redirected_to collection_path(@collection)
      assert_equal [@first.id], @collection.collection_items.pluck(:bullet_id)
      patch collection_item_path(@collection, bullet_id: foreign.id), params: { lane: 'parked' }
      assert_response :not_found
      assert_equal [@first.id], @collection.collection_items.pluck(:bullet_id)
    end

    test 'invalid lane and invalid destination do not change placements' do
      patch collection_item_path(@collection, bullet_id: @first.id), params: { lane: 'other' }
      assert_response :unprocessable_entity
      patch collection_item_path(@collection, bullet_id: @first.id), params: { lane: 'parked', before_id: @second.id }
      assert_response :unprocessable_entity
      assert_empty @collection.collection_items
    end
  end
end
