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

  test 'EPUB detail offers separate open and download actions' do
    bullet = create_file_bullet!(@user, filename: 'book.epub', content_type: 'application/epub+zip')

    get attachment_path(bullet)

    assert_response :success
    assert_select 'i[style*="--icon-book-2"]', count: 1
    assert_select 'a[href=?][target="_blank"][rel="noopener noreferrer"]',
                  rails_blob_path(bullet.file, disposition: 'inline'), text: 'Open file'
    assert_select 'a[href=?][download="book.epub"]',
                  rails_blob_path(bullet.file, disposition: 'attachment'), text: 'Download'
    assert_select 'iframe, [data-controller="reader"]', count: 0
  end

  test 'EPUB filename fallback uses the book icon in the gallery and timeline' do
    bullet = create_file_bullet!(@user, filename: 'BOOK.EPUB', content_type: 'application/octet-stream')

    get attachments_path

    assert_response :success
    assert_select "li#bullet_#{bullet.id} i[style*='--icon-book-2']", count: 1

    get bullets_path

    assert_response :success
    assert_select "#bullet_#{bullet.id} a[href=?][aria-label='Open BOOK.EPUB']",
                  attachment_path(bullet) do
      assert_select "i[style*='--icon-book-2']", count: 1
    end
  end

  test 'all file previews open their attachment page with shared open and download actions' do
    [['picture.png', 'image/png'], ['notes.txt', 'text/plain']].each do |filename, type|
      bullet = create_file_bullet!(@user, filename: filename, content_type: type)

      get bullets_path

      assert_response :success
      assert_select "#bullet_#{bullet.id} a[href=?][data-turbo-frame='_top']", attachment_path(bullet)

      get attachment_path(bullet)

      assert_response :success
      assert_select 'main.attachment--detail > .attachment--content', count: 1
      assert_select 'a[href=?]', rails_blob_path(bullet.file, disposition: 'inline'), text: 'Open file'
      assert_select 'a[href=?]', rails_blob_path(bullet.file, disposition: 'attachment'), text: 'Download'
    end
  end

  private

  def file_bullet!(user, filename:)
    create_file_bullet!(user, filename: filename, content_type: 'application/pdf', io: StringIO.new('%PDF-1.4'))
  end
end
