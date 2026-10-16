# frozen_string_literal: true

require 'application_system_test_case'

class ComposerSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
    visit bullets_path
  end

  test 'creates a text bullet through the shared composer' do
    editor = find('#bullet_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('Fresh note')
    find('#bullet_composer .composer--submit-button').click

    assert_text 'Fresh note'
    assert_equal 'Fresh note', @user.bullets.reload.last.body_as_text
  end

  test 'enter in the editor submits the composer' do
    editor = find('#bullet_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('Keyboard note', :enter)

    assert_text 'Keyboard note'
    assert_equal 'Keyboard note', @user.bullets.reload.last.body_as_text
  end

  test 'optimistic pending templates render without marker circles' do
    text_html = page.evaluate_script(
      "document.querySelector('[data-composer-target=\"pendingTextTemplate\"]').innerHTML"
    )
    file_html = page.evaluate_script(
      "document.querySelector('[data-composer-attachment-target=\"pendingFileTemplate\"]').innerHTML"
    )

    assert_not_includes text_html, 'bullet--marker'
    assert_not_includes file_html, 'bullet--marker'
  end

  test 'shift f focuses the composer from elsewhere on the page' do
    assert_selector '#bullet_composer lexxy-editor.hotkey-hint[data-hotkey="F"]'
    find('body').send_keys([:shift, 'f'])

    assert_selector '#bullet_composer lexxy-editor .lexxy-editor__content:focus'
  end

  test 'shift d opens the file picker from elsewhere on the daylog' do
    assert_selector '#bullet_composer button[aria-label="Attach file"].hotkey-hint[data-hotkey="D"]'
    page.execute_script(<<~JS)
      const input = document.querySelector('#bullet_composer_attachment_file')
      input.click = () => { input.dataset.pickerOpened = 'true' }
    JS

    find('body').send_keys([:shift, 'd'])

    assert_selector '#bullet_composer_attachment_file[data-picker-opened="true"]', visible: :all
  end

  test 'the editor has no formatting toolbar' do
    assert_selector '#bullet_composer lexxy-editor'
    assert_no_selector '#bullet_composer lexxy-toolbar'
    assert_no_selector '#bullet_composer [aria-label="Toggle formatting toolbar"]'
  end

  test 'typing swaps the paperclip for the send button' do
    editor = find('#bullet_composer lexxy-editor .lexxy-editor__content')
    send = '#bullet_composer .composer--submit-button'
    attach = '#bullet_composer button[aria-label="Attach file"]'

    assert_selector attach
    assert_no_selector send

    editor.send_keys('Text draft')

    assert_selector send
    assert_no_selector attach

    editor.send_keys(*([:backspace] * 'Text draft'.length))

    assert_selector attach
    assert_no_selector send
  end

  test 'chat composer docks over the full-height scroller' do
    assert_selector '.timeline--window > .timeline--scroller[data-controller~="timeline-scroll"]'
    assert_selector '.timeline--window > #composer_dock > #bullet_composer'
  end
end
