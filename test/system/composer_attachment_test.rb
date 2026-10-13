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
end
