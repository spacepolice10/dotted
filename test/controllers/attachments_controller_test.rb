# frozen_string_literal: true

require 'test_helper'

class AttachmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'show renders a file owned by an attachment bullet' do
    bullet = file_bullet!(@user, filename: 'report.pdf')

    get attachment_path(bullet)

    assert_response :success
    assert_match 'report.pdf', response.body
  end

  test 'show returns not found for another users attachment bullet file' do
    bullet = file_bullet!(users(:two), filename: 'foreign.pdf')

    get attachment_path(bullet)

    assert_response :not_found
  end

  test 'show returns not found for a bullet without a file' do
    bullet = create_bullet!(@user, body: 'No file')

    get attachment_path(bullet)

    assert_response :not_found
  end

  test 'index lists owned files and excludes another users files' do
    bullet = file_bullet!(@user, filename: 'report.pdf')
    foreign_bullet = file_bullet!(users(:two), filename: 'foreign.pdf')

    get attachments_path

    assert_response :success
    assert_select 'nav.tabbar--back a[href=?][aria-label=?]', search_path, 'Back', text: 'Back'
    assert_select 'a[aria-label="Back to Home"]', count: 0
    assert_select "li#bullet_#{bullet.id} a[href=?]", attachment_path(bullet), text: /report.pdf/
    assert_select "li#bullet_#{foreign_bullet.id}", count: 0
  end

  test 'index renders an image with a filename pill' do
    bullet = create_file_bullet!(@user, filename: 'picture.png')

    get attachments_path

    assert_response :success
    assert_select "li#bullet_#{bullet.id} a[href=?] img[alt=?]", attachment_path(bullet), 'picture.png'
    assert_select "li#bullet_#{bullet.id} .pill.attachment--preview-name", text: 'picture.png'
    assert_select "li#bullet_#{bullet.id} a[href=?]", bullet_path(bullet), count: 0
  end

  private

  def file_bullet!(user, filename:)
    create_file_bullet!(user, filename: filename, content_type: 'application/pdf', io: StringIO.new('%PDF-1.4'))
  end
end
