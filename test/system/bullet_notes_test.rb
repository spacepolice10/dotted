# frozen_string_literal: true

require 'application_system_test_case'

class BulletNotesSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @bullet = create_bullet!(@user, body: 'Quick thought')
  end

  test 'add, open, and edit a rich note' do
    visit bullets_path
    find("label[for='select_checkbox_bullet_#{@bullet.id}']", match: :first).click
    click_button 'Note', exact: true

    assert_selector 'dialog#note_dialog[open] lexxy-toolbar'
    editor = find('#note_editor .lexxy-editor__content[contenteditable=true]')
    editor.click
    editor.send_keys('Detailed thought', :enter, 'Second paragraph')
    click_button 'Save note'

    assert_no_selector 'dialog#note_dialog[open]'
    find('.note-preview', text: 'Detailed thought').click
    assert_current_path bullet_path(@bullet)
    assert_selector '.bullet-note', text: 'Detailed thought'
    assert_selector '.bullet-note', text: 'Second paragraph'
    assert_selector '.bullet', count: 1

    find("label[for='select_checkbox_bullet_#{@bullet.id}']", match: :first).click
    click_button 'Note', exact: true
    assert_selector '#note_editor .lexxy-editor__content', text: 'Detailed thought'
  end
end
