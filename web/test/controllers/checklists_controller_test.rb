# frozen_string_literal: true

require 'test_helper'

class ChecklistsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @bullet = create_bullet!(@user, body: 'Prepare launch')
  end

  test 'new checklist editor loads in its own turbo frame' do
    get new_bullet_checklist_path(@bullet)

    assert_response :success
    assert_select 'turbo-frame#checklist_editor form[action=?]', bullet_checklist_path(@bullet)
    assert_select '.checklist-editor--items input[name*="[items_attributes]"][type=text]', count: 1
    assert_select '.checklist-editor--items > button', text: 'Add item', count: 1
    assert_select '.checklist-editor--actions button', text: 'Save', count: 1
    assert_select '.checklist-editor--actions button[name=resurface][value="1"]', text: 'Save & Resurface', count: 1
  end

  test 'create saves ordered items without changing the bullet date' do
    @bullet.update!(pops_on: Date.current - 5)

    post bullet_checklist_path(@bullet), params: {
      checklist: { items_attributes: {
        '0' => { text: ' Draft outline ', position: 0 },
        '1' => { text: 'Review copy', position: 1 }
      } }
    }, as: :turbo_stream

    assert_response :success
    assert_equal ['Draft outline', 'Review copy'], @bullet.reload.checklist.items.pluck(:text)
    assert_equal Date.current - 5, @bullet.pops_on
    assert_select "turbo-stream[action=append][target=timeline_section_current_date]", count: 0
    assert_select '.bullet-checklist--item', text: /Draft outline/
    assert_select '.bullet-checklist--item', text: /Review copy/
  end

  test 'resurface option saves and brings the bullet to today' do
    @bullet.update!(pops_on: Date.current - 5)

    post bullet_checklist_path(@bullet), params: {
      resurface: '1',
      checklist: { items_attributes: { '0' => { text: 'Draft', position: 0 } } }
    }, as: :turbo_stream

    assert_response :success
    assert_equal Date.current, @bullet.reload.pops_on
    assert_equal 'Draft', @bullet.checklist.items.first.text
    assert_select "turbo-stream[action=append][target=timeline_section_current_date] #bullet_#{@bullet.id}"
  end

  test 'blank checklist is rejected' do
    assert_no_difference 'Checklist.count' do
      post bullet_checklist_path(@bullet), params: {
        checklist: { items_attributes: { '0' => { text: ' ', position: 0 } } }
      }, as: :turbo_stream
    end

    assert_response :unprocessable_entity
    assert_select 'turbo-frame#checklist_editor [role=alert]', text: /at least one item/
  end

  test 'editing can add and remove items without changing completed state' do
    checklist = @bullet.create_checklist!(items_attributes: {
      '0' => { text: 'First', position: 0 },
      '1' => { text: 'Second', position: 1 }
    })
    first, second = checklist.items.to_a
    first.set_completed!(completed: true)

    patch bullet_checklist_path(@bullet), params: {
      checklist: { items_attributes: {
        '0' => { id: first.id, text: 'First revised', position: 0 },
        '1' => { id: second.id, text: 'Second', position: 1, _destroy: '1' },
        '2' => { text: 'Third', position: 1 }
      } }
    }, as: :turbo_stream

    assert_response :success
    assert_equal ['First revised', 'Third'], checklist.items.reload.pluck(:text)
    assert checklist.items.first.completed?
    assert checklist.reload.items.first.completed?
  end

  test 'removing every item removes the optional checklist' do
    checklist = @bullet.create_checklist!(items_attributes: { '0' => { text: 'Only step', position: 0 } })
    item = checklist.items.first

    patch bullet_checklist_path(@bullet), params: {
      checklist: { items_attributes: { '0' => { id: item.id, _destroy: '1' } } }
    }, as: :turbo_stream

    assert_response :success
    assert_not Checklist.exists?(checklist.id)
    assert_select '.bullet-checklist', count: 0
  end

  test 'another account cannot view or change a checklist' do
    other = create_bullet!(users(:two), body: 'Private')
    other.create_checklist!(items_attributes: { '0' => { text: 'Private task', position: 0 } })

    get edit_bullet_checklist_path(other)
    assert_response :not_found
    patch bullet_checklist_path(other), params: {
      checklist: { items_attributes: { '0' => { text: 'Intrusion', position: 0 } } }
    }
    assert_response :not_found
    assert_equal 'Private task', other.reload.checklist.items.first.text
  end
end
