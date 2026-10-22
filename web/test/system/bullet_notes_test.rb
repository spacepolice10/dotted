# frozen_string_literal: true

require 'application_system_test_case'

class BulletNotesSystemTest < ApplicationSystemTestCase
  setup do
    page.current_window.resize_to(1400, 1400)
    @user = users(:one)
    sign_in_as(@user)
    @bullet = create_bullet!(@user, body: 'Quick thought')
  end

  test 'add and edit a note without navigating' do
    original_date = Date.current - 5
    @bullet.update!(pops_on: original_date)
    visit bullets_path
    find("label[for='select_checkbox_bullet_#{@bullet.id}']", match: :first).click
    click_button 'Note', exact: true

    assert_selector 'dialog#note_dialog[open] lexxy-toolbar'
    editor = find('#note_editor .lexxy-editor__content[contenteditable=true]')
    editor.click
    editor.send_keys('Detailed thought', :enter, 'Second paragraph')
    click_button 'Save', exact: true

    assert_no_selector 'dialog#note_dialog[open]'
    find('.note-preview', text: 'Detailed thought').click
    assert_current_path bullets_path
    assert_selector '.note-preview', text: 'Second paragraph'
    assert_no_selector '.note-preview a'
    assert_no_selector '.note-preview button'
    assert_equal Date.current, @bullet.reload.pops_on

    find("label[for='select_checkbox_bullet_#{@bullet.id}']", match: :first).click
    click_button 'Note', exact: true
    assert_selector '#note_editor .lexxy-editor__content', text: 'Detailed thought'
    editor = find('#note_editor .lexxy-editor__content[contenteditable=true]')
    editor.click
    editor.send_keys(:end, ' Updated')
    click_button 'Save', exact: true

    assert_no_selector 'dialog#note_dialog[open]'
    assert_current_path bullets_path
    assert_selector '.note-preview', text: 'Updated'
    assert_selector '#timeline_section_current_date .note-preview', text: 'Updated'
    assert_no_selector ".timeline--section:not(#timeline_section_current_date) #bullet_#{@bullet.id}"
    assert_equal Date.current, @bullet.reload.pops_on
  end
end
