# frozen_string_literal: true

require 'test_helper'

class ChecklistItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @bullet = create_bullet!(@user, body: 'Prepare launch', pops_on: Date.current - 4)
    @checklist = @bullet.create_checklist!(items_attributes: {
      '0' => { text: 'Draft', position: 0 },
      '1' => { text: 'Review', position: 1 }
    })
    @item = @checklist.items.first
  end

  test 'checking and unchecking update the item without resurfacing' do
    patch bullet_checklist_item_path(@bullet, @item), params: { checklist_item: { completed: '1' } }, as: :turbo_stream

    assert_response :success
    assert @item.reload.completed?
    assert_equal Date.current - 4, @bullet.reload.pops_on
    assert_select 'turbo-stream[action=replace][targets] .bullet-checklist input[checked]', count: 1

    patch bullet_checklist_item_path(@bullet, @item), params: { checklist_item: { completed: '0' } }, as: :turbo_stream

    assert_response :success
    assert_not @item.reload.completed?
    assert_select 'turbo-stream[action=replace][targets] .bullet-checklist input[checked]', count: 0
  end

  test 'item must belong to the bullet and the signed in account' do
    other = create_bullet!(users(:two), body: 'Private')
    other_item = other.create_checklist!(items_attributes: { '0' => { text: 'Private task', position: 0 } }).items.first

    patch bullet_checklist_item_path(@bullet, other_item), params: { checklist_item: { completed: '1' } }
    assert_response :not_found
    patch bullet_checklist_item_path(other, other_item), params: { checklist_item: { completed: '1' } }
    assert_response :not_found
    assert_not other_item.reload.completed?
  end

  test 'invalid state is rejected' do
    patch bullet_checklist_item_path(@bullet, @item), params: { checklist_item: { completed: 'later' } }

    assert_response :bad_request
    assert_not @item.reload.completed?
  end
end
