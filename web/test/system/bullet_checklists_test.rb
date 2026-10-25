# frozen_string_literal: true

require 'application_system_test_case'

class BulletChecklistsSystemTest < ApplicationSystemTestCase
  setup do
    page.current_window.resize_to(1400, 1400)
    @user = users(:one)
    sign_in_as(@user)
    @bullet = create_bullet!(@user, body: 'Prepare launch')
  end

  test 'create edit check and uncheck a checklist from the bullet menu' do
    visit bullets_path
    find("#bullet_#{@bullet.id} .bullet--select-square").click
    click_button 'Checklist', exact: true

    assert_selector 'dialog#checklist_dialog[open] turbo-frame#checklist_editor'
    assert_operator find('#checklist_dialog').evaluate_script('this.getBoundingClientRect().height'), :<, 600
    find('#checklist_editor .checklist-editor--items input[type=text]').click
    focus_spacing = page.evaluate_script(<<~JS)
      (() => {
        const list = document.querySelector('.checklist-editor--items').getBoundingClientRect()
        const field = document.querySelector('.checklist-editor--items input[type=text]').getBoundingClientRect()
        return { inline: field.left - list.left, block: field.top - list.top }
      })()
    JS
    assert_operator focus_spacing['inline'], :>=, 5
    assert_operator focus_spacing['block'], :>=, 5
    within '#checklist_editor' do
      find('input[type=text]').fill_in with: 'Draft outline'
      click_button 'Add item'
      all('input[type=text]').last.fill_in with: 'Review copy'
      click_button 'Save', exact: true
    end

    assert_no_selector 'dialog#checklist_dialog[open]'
    within "#bullet_#{@bullet.id} .bullet-checklist" do
      assert_no_text 'Checklist'
      assert_no_text 'Progress'
      assert_selector '.bullet-checklist--item', count: 2
      assert_text 'Draft outline'
      assert_text 'Review copy'
      find('label', text: 'Draft outline').click
      assert_selector 'input[type=checkbox][checked]', visible: false, count: 1
      find('label', text: 'Draft outline').click
      assert_selector 'input[type=checkbox][checked]', visible: false, count: 0
    end
    assert_not find("#bullet_#{@bullet.id} > input[data-bullet-menu-target=checkbox]", visible: false).checked?
    assert_no_selector '.bullet-menu:not([hidden])'
    assert page.evaluate_script(<<~JS)
      (() => {
        const bullet = document.querySelector('#bullet_#{@bullet.id}')
        const selector = getComputedStyle(bullet.querySelector('.bullet--select-square'), '::before')
        const label = bullet.querySelector('.bullet-checklist--item label')
        const text = label.querySelector('.bullet-checklist--text')
        const labelStyle = getComputedStyle(label)
        const checklistCircle = getComputedStyle(label, '::before')
        const circleMiddle = label.getBoundingClientRect().top + parseFloat(labelStyle.paddingTop) +
          parseFloat(checklistCircle.marginTop) + parseFloat(checklistCircle.height) / 2
        const firstLineMiddle = text.getBoundingClientRect().top + parseFloat(labelStyle.lineHeight) / 2
        const rows = bullet.querySelectorAll('.bullet-checklist--items li')
        const rowGap = rows[1].getBoundingClientRect().top - rows[0].getBoundingClientRect().bottom
        return selector.width === checklistCircle.width && selector.height === checklistCircle.height &&
          checklistCircle.borderRadius === '50%' && Math.abs(circleMiddle - firstLineMiddle) <= 2 &&
          parseFloat(labelStyle.paddingBottom) === 0 && rowGap <= 4
      })()
    JS

    find("#bullet_#{@bullet.id} .bullet--select-square").click
    click_button 'Checklist', exact: true
    within '#checklist_editor' do
      assert_field 'Checklist item', with: 'Draft outline', match: :first
      all('button[aria-label="Remove item"]').last.click
      click_button 'Save', exact: true
    end

    assert_no_selector 'dialog#checklist_dialog[open]'
    assert_selector "#bullet_#{@bullet.id} .bullet-checklist--item", count: 1, wait: 10
    within "#bullet_#{@bullet.id} .bullet-checklist" do
      assert_no_text 'Review copy'
    end
    assert_equal 1, @bullet.reload.checklist.items.count

    find("#bullet_#{@bullet.id} .bullet--select-square").click
    click_button 'Checklist', exact: true
    within '#checklist_editor' do
      find('button[aria-label="Remove item"]').click
      click_button 'Save', exact: true
    end
    assert_no_selector 'dialog#checklist_dialog[open]'
    assert_no_selector "#bullet_#{@bullet.id} .bullet-checklist"
  end

  test 'Enter inserts and focuses a new item without saving the checklist' do
    visit bullets_path
    find("#bullet_#{@bullet.id} .bullet--select-square").click
    click_button 'Checklist', exact: true

    within '#checklist_editor' do
      find('.checklist-editor--items input[type=text]').fill_in with: 'Draft'
      click_button 'Add item'
      all('.checklist-editor--items input[type=text]').last.fill_in with: 'Review'
      all('.checklist-editor--items input[type=text]').first.send_keys(:enter)

      assert_selector '.checklist-editor--items input[type=text]', count: 3
      assert page.evaluate_script(<<~JS)
        (() => {
          const fields = document.querySelectorAll('.checklist-editor--items input[type=text]')
          return document.activeElement === fields[1]
        })()
      JS
      all('.checklist-editor--items input[type=text]')[1].fill_in with: 'Refine'
    end

    assert_selector 'dialog#checklist_dialog[open]'
    assert_not @bullet.reload.with_checklist?
    within '#checklist_editor' do
      click_button 'Save', exact: true
    end
    assert_no_selector 'dialog#checklist_dialog[open]'
    assert_selector "#bullet_#{@bullet.id} .bullet-checklist--item", count: 3
    assert_equal %w[Draft Refine Review], @bullet.reload.checklist.items.pluck(:text)
  end

  test 'checking a collection bullet leaves it in its lane and keeps the list scroll position' do
    collection = create_collection!(@user, name: 'Launch')
    @bullet.update!(collection: collection)
    @bullet.create_checklist!(items_attributes: { '0' => { text: 'Draft', position: 0 } })
    14.times { |index| create_bullet!(@user, body: "Other #{index}", collection: collection) }

    visit collection_path(collection)
    page.execute_script("document.querySelector('.collection--lane[data-lane=unsorted] .collection--bullets').scrollTop = 100")
    before = page.evaluate_script("document.querySelector('.collection--lane[data-lane=unsorted] .collection--bullets').scrollTop")

    page.execute_script("document.querySelector('#bullet_#{@bullet.id} .bullet-checklist input[type=checkbox]').click()")
    within "#bullet_#{@bullet.id} .bullet-checklist" do
      assert_selector 'input[type=checkbox][checked]', visible: false, count: 1
    end

    assert_selector ".collection--lane[data-lane=unsorted] #bullet_#{@bullet.id}"
    after = page.evaluate_script("document.querySelector('.collection--lane[data-lane=unsorted] .collection--bullets').scrollTop")
    assert_in_delta before, after, 1
  end

  test 'mobile checklist action opens from More and is hidden for multiple bullets' do
    page.current_window.resize_to(390, 844)
    other = create_bullet!(@user, body: 'Another bullet')

    visit bullets_path
    find("#bullet_#{@bullet.id} .bullet--select-square").click
    click_button 'More', exact: true
    within '#more_dialog' do
      assert_button 'Checklist', exact: true
      click_button 'Checklist', exact: true
    end
    assert_selector '#checklist_dialog[open] .checklist-editor'
    find('#checklist_dialog').send_keys(:escape)

    find("#bullet_#{other.id} .bullet--select-square").click
    click_button 'More', exact: true
    within '#more_dialog' do
      assert_no_button 'Checklist', exact: true
    end
  end
end
