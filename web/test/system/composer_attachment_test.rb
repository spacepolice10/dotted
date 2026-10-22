# frozen_string_literal: true

require 'application_system_test_case'

class ComposerAttachmentSystemTest < ApplicationSystemTestCase
  PIXEL_PNG = Base64.decode64(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
  ).freeze

  setup do
    @user = users(:one)
    sign_in_as(@user)
    visit bullets_path
  end

  test 'choosing a file inserts a pending bullet then replaces it' do
    path = Rails.root.join("tmp/pixel-#{SecureRandom.hex(4)}.png")
    File.binwrite(path, PIXEL_PNG)

    attach_file('bullet[file]', path, make_visible: true)

    assert_difference -> { @user.bullets.count }, 1 do
      assert_selector '#timeline_section_current_date turbo-frame.bullet:not(.bullet--pending)', wait: 10
    end

    bullet = @user.bullets.reload.last
    image_bullet = find("#bullet_#{bullet.id}")
    assert_selector "##{image_bullet[:id]} .attachment--preview .pill", text: File.basename(path)
    assert_selector "##{image_bullet[:id]} .bullet--select-checkbox[aria-label='Select bullet']"
    image_style = page.evaluate_script(<<~JS)
      (() => {
        const body = document.querySelector('##{image_bullet[:id]} .bullet--body')
        const style = getComputedStyle(body)
        const pill = document.querySelector('##{image_bullet[:id]} .attachment--preview-name')
        return { padding: style.paddingTop, overflow: style.overflow, border: style.borderTopColor,
                 pillBorder: getComputedStyle(pill).borderTopColor }
      })()
    JS
    assert_equal '0px', image_style['padding']
    assert_equal 'hidden', image_style['overflow']

    find("##{image_bullet[:id]} .attachment--preview-name").click
    assert_selector "##{image_bullet[:id]} [data-bullet-menu-target=checkbox]:checked", visible: :all
    assert_current_path bullets_path
    selected_style = page.evaluate_script(<<~JS)
      (() => {
        const bullet = document.querySelector('##{image_bullet[:id]}')
        return {
          border: getComputedStyle(bullet.querySelector('.bullet--body')).borderTopColor,
          pillBorder: getComputedStyle(bullet.querySelector('.attachment--preview-name')).borderTopColor,
          tint: getComputedStyle(bullet.querySelector('.attachment--preview-picture'), '::after').opacity
        }
      })()
    JS
    assert_equal image_style['border'], selected_style['border']
    assert_not_equal image_style['pillBorder'], selected_style['pillBorder']
    assert_equal '1', selected_style['tint']

    zoom_link = find("##{image_bullet[:id]} .attachment--preview-picture")
    assert_equal 'false', zoom_link['data-turbo']
    zoom_link.click
    assert_current_path %r{/rails/active_storage/disk/.*/#{Regexp.escape(File.basename(path))}}
    assert_selector "img", count: 1

    assert bullet.file.attached?
    assert_equal File.basename(path), bullet.file.filename.to_s
    assert_empty bullet.body_as_text
    assert bullet.client_id.present?
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test 'a typed bullet is not a file bullet' do
    editor = find('#bullet_composer lexxy-editor .lexxy-editor__content')
    editor.send_keys('Fresh note')
    find('#bullet_composer .composer--submit-button').click

    assert_selector '#timeline_section_current_date turbo-frame.bullet:not(.bullet--pending)',
                    text: 'Fresh note', wait: 10

    bullet = @user.bullets.reload.last
    assert_not bullet.file.attached?
    assert_equal 'Fresh note', bullet.body_as_text
    assert bullet.client_id.present?
  end

  test 'pasting files uploads each file and preserves the draft' do
    find('#bullet_composer lexxy-editor .lexxy-editor__content').send_keys('Unfinished note')

    paste_files([
      { name: 'pasted.png', type: 'image/png', bytes: PIXEL_PNG.bytes },
      { name: 'notes.txt', type: 'text/plain', bytes: 'File contents'.bytes }
    ])

    assert_selector '#timeline_section_current_date .attachment--preview-name', text: 'pasted.png', wait: 10
    assert_selector '#timeline_section_current_date .attachment--preview-name', text: 'notes.txt', wait: 10
    assert_selector '#bullet_composer lexxy-editor', text: 'Unfinished note'
    assert_no_selector '#bullet_composer action-text-attachment'

    bullets = @user.bullets.reload.select { |bullet| bullet.file.attached? }
    assert_equal ['notes.txt', 'pasted.png'], bullets.map { |bullet| bullet.file.filename.to_s }.sort
    assert bullets.all? { |bullet| bullet.body_as_text.blank? }
  end

  test 'pasting an oversized file shows the upload size error' do
    paste_files([{ name: 'large.txt', type: 'text/plain', size: 5 * 1024 * 1024 + 1 }])

    assert_text 'File is too large (maximum is 5 MB)'
    assert_no_selector '.bullet--pending'
    assert_not @user.bullets.reload.any? { |bullet| bullet.file.attached? }
  end

  test 'pasting plain text keeps the normal paste behavior' do
    prevented = page.evaluate_script(<<~JS)
      (() => {
        const clipboardData = new DataTransfer()
        clipboardData.setData('text/plain', 'Pasted note')
        const event = new ClipboardEvent('paste', { clipboardData, bubbles: true, cancelable: true })
        document.querySelector('#bullet_composer').dispatchEvent(event)
        return event.defaultPrevented
      })()
    JS

    assert_equal false, prevented
    assert_no_selector '.bullet--pending'
  end

  private

  def paste_files(files)
    page.execute_script(<<~JS, files)
      const clipboardData = new DataTransfer()
      arguments[0].forEach(({ name, type, bytes, size }) => {
        const content = new Uint8Array(bytes || size)
        clipboardData.items.add(new File([content], name, { type }))
      })
      document.querySelector('#bullet_composer lexxy-editor .lexxy-editor__content').dispatchEvent(
        new ClipboardEvent('paste', { clipboardData, bubbles: true, cancelable: true, composed: true })
      )
    JS
  end

end
