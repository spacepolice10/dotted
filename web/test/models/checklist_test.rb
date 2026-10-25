# frozen_string_literal: true

require 'test_helper'

class ChecklistTest < ActiveSupport::TestCase
  test 'a bullet owns one checklist and deletes its items with it' do
    bullet = create_bullet!(users(:one), body: 'Prepare launch')
    checklist = bullet.create_checklist!(items_attributes: {
      '0' => { text: 'Draft', position: 0 },
      '1' => { text: 'Review', position: 1 }
    })
    item_ids = checklist.items.pluck(:id)

    assert_not Checklist.new(bullet: bullet, items: [ChecklistItem.new(text: 'Duplicate')]).valid?

    bullet.association(:checklist).reset
    bullet.destroy!

    assert_not Checklist.exists?(checklist.id)
    assert_not ChecklistItem.where(id: item_ids).exists?
  end

  test 'items retain their display order and completed state' do
    bullet = create_bullet!(users(:one), body: 'Prepare launch')
    checklist = bullet.create_checklist!(items_attributes: {
      '0' => { text: 'Second', position: 1 },
      '1' => { text: 'First', position: 0 }
    })

    assert_equal ['First', 'Second'], checklist.items.reload.pluck(:text)
    assert_not checklist.items.first.completed?

    checklist.items.first.set_completed!(completed: true)
    assert checklist.reload.items.first.completed?
  end
end
