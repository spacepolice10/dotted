# frozen_string_literal: true

require 'test_helper'

class NotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @bullet = create_bullet!(@user, body: 'Quick thought')
  end

  test 'editor loads existing rich note in a turbo frame' do
    @bullet.create_note!(content: '<h2>Existing detail</h2>')

    get edit_bullet_note_path(@bullet)

    assert_response :success
    assert_select 'turbo-frame#note_editor lexxy-editor[preset=note]'
    assert_select 'button', text: 'Save', count: 1
    assert_match 'Existing detail', response.body
  end

  test 'saving a long rich note updates the bullet preview and detail' do
    content = "<h2>Details</h2><p>#{'Elaboration ' * 1000}</p>"
    patch bullet_note_path(@bullet), params: { note: { content: content, body: 'Unwanted change' } }, as: :turbo_stream

    assert_response :success
    assert_equal 'Quick thought', @bullet.reload.body_as_text
    assert_includes @bullet.note.content.body.to_html, '<h2>Details</h2>'
    assert_select 'turbo-stream[action=replace] .note-preview', text: /Details/
    assert_select 'turbo-stream[action=refresh]', count: 0
  end

  test 'clearing the note removes its preview' do
    @bullet.create_note!(content: 'Old detail')
    patch bullet_note_path(@bullet), params: { note: { content: '' } }, as: :turbo_stream

    assert_response :success
    assert @bullet.reload.note.content.blank?
  end

  test 'editing reuses the existing note' do
    note = @bullet.create_note!(content: 'First version')
    assert_no_difference 'Note.count' do
      patch bullet_note_path(@bullet), params: { note: { content: '<p>Revised</p>' } }
    end
    assert_redirected_to bullet_path(@bullet)
    assert_equal 'Revised', note.reload.content.to_plain_text
  end

  test 'creating a note brings a past bullet to today' do
    @bullet.update!(pops_on: Date.current - 5)

    patch bullet_note_path(@bullet), params: { note: { content: 'New note' } }, as: :turbo_stream

    assert_response :success
    assert_equal Date.current, @bullet.reload.pops_on
    assert_select "turbo-stream[action=append][target=timeline_section_current_date] #bullet_#{@bullet.id}"
    assert_select 'turbo-stream[action=refresh]', count: 0
    assert_equal 0, @bullet.postponements_number
    assert_empty @bullet.activities
  end

  test 'editing a note brings a future bullet to today' do
    @bullet.create_note!(content: 'Existing note')
    @bullet.update!(pops_on: Date.current + 5)

    patch bullet_note_path(@bullet), params: { note: { content: 'Updated note' } }, as: :turbo_stream

    assert_response :success
    assert_equal Date.current, @bullet.reload.pops_on
    assert_select "turbo-stream[action=append][target=timeline_section_current_date] #bullet_#{@bullet.id}"
    assert_select 'turbo-stream[action=refresh]', count: 0
    assert_equal 0, @bullet.postponements_number
    assert_empty @bullet.activities
  end

  test 'saving a new note automatically resurfaces the bullet' do
    date = Date.current - 5
    @bullet.update!(pops_on: date)

    patch bullet_note_path(@bullet), params: { note: { content: 'New note' } }, as: :turbo_stream

    assert_response :success
    assert_equal 'New note', @bullet.reload.note.content.to_plain_text
    assert_equal Date.current, @bullet.pops_on
    assert_empty @bullet.activities
  end

  test 'saving an existing note automatically resurfaces the bullet' do
    @bullet.create_note!(content: 'Existing note')
    date = Date.current + 5
    @bullet.update!(pops_on: date)

    patch bullet_note_path(@bullet), params: { note: { content: 'Updated note' } }, as: :turbo_stream

    assert_response :success
    assert_equal 'Updated note', @bullet.reload.note.content.to_plain_text
    assert_equal Date.current, @bullet.pops_on
  end

  test 'deleting a bullet deletes its note and rich content' do
    note = @bullet.create_note!(content: 'Detail')
    rich_text_id = note.rich_text_content.id
    @bullet.destroy!
    assert_not Note.exists?(note.id)
    assert_not ActionText::RichText.exists?(rich_text_id)
  end

  test 'notes are scoped to the signed in user' do
    other = create_bullet!(users(:two), body: 'Private')
    get edit_bullet_note_path(other)
    assert_response :not_found
    patch bullet_note_path(other), params: { note: { content: 'Intrusion' } }
    assert_response :not_found
    assert other.reload.note.blank?
  end
end
