# frozen_string_literal: true

require 'test_helper'

class BulletTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'pops_on defaults to today' do
    bullet = create_bullet!(@user, body: 'Fresh')

    assert_equal Date.current, bullet.pops_on
  end

  test 'text is the default marker and done swaps it for a check' do
    bullet = create_bullet!(@user, body: 'Do it')

    assert_equal :circle, bullet.marker_icon
    bullet.complete!
    assert_equal :check, bullet.marker_icon
  end

  test 'complete and uncomplete toggle done' do
    bullet = create_bullet!(@user, body: 'Do it')

    assert_not bullet.done?
    bullet.complete!
    assert bullet.reload.done?
    assert_not_nil bullet.done_at
    bullet.uncomplete!
    assert_not bullet.reload.done?
    assert_nil bullet.done_at
  end

  test 'a file and a body together are invalid' do
    bullet = @user.bullets.new(body: 'Both')
    bullet.file.attach(create_blob!(filename: 'a.png', content_type: 'image/png'))

    assert_not bullet.valid?
  end

  test 'neither a file nor text is invalid' do
    assert_not @user.bullets.new.valid?
  end

  test 'blank client_id normalizes to nil' do
    bullet = create_bullet!(@user, body: 'Note', client_id: '')

    assert_nil bullet.client_id
  end

  test 'client_id must look like a uuid' do
    bullet = @user.bullets.new(body: 'Note', client_id: 'not-a-uuid')

    assert_not bullet.valid?
    assert_includes bullet.errors[:client_id], 'is invalid'
  end


  test 'a file within the size limit is accepted' do
    bullet = @user.bullets.new
    bullet.file.attach(create_blob!(filename: 'small.bin', content_type: 'application/octet-stream'))

    assert bullet.valid?
  end

  test 'a file one byte over the limit is rejected' do
    bullet = @user.bullets.new
    bullet.file.attach(create_blob!(filename: 'big.bin', content_type: 'application/octet-stream'))
    bullet.file.blob.update!(byte_size: 5.megabytes + 1)

    assert_not bullet.valid?
    assert_includes bullet.errors[:file].join, 'too large'
  end

  test 'a bullet whose blob was purged keeps its filename and fails re-save readably' do
    bullet = create_file_bullet!(@user)
    bullet.file.purge
    bullet.reload

    assert_equal 'pixel.png', bullet.name
    assert_not bullet.valid?
  end

  test 'a very long filename saves and truncates safely in the search index' do
    bullet = create_file_bullet!(@user)
    bullet.update!(filename: "#{'n' * 300}.png")

    assert bullet.valid?
    assert bullet.search_body.bytesize <= Search::Record::SEARCH_CONTENT_SIZE
  end

  test 'an attachment bullet is searchable by its filename' do
    bullet = create_file_bullet!(@user, filename: 'quarterly report.pdf')

    assert_equal 'quarterly report.pdf', bullet.reload.filename
    assert_includes bullet.search_body, 'quarterly report.pdf'
  end

  test 'name falls back to the filename when the body is blank' do
    bullet = create_file_bullet!(@user)

    assert_equal 'pixel.png', bullet.name
  end

  test 'collect tags the bullet and leaves it on the timeline' do
    collection = create_collection!(@user, name: 'Ideas')
    bullet = create_bullet!(@user, body: 'File me')

    timeline = Timeline.new(@user)
    assert_includes timeline.filtered, bullet
    bullet.collect!(collection_id: collection.id)

    assert_equal collection, bullet.reload.collection
    assert_includes timeline.filtered, bullet
  end

  test 'collect moves a bullet between collections' do
    first = create_collection!(@user, name: 'ideas')
    second = create_collection!(@user, name: 'later')
    bullet = create_bullet!(@user, body: 'Shared')

    bullet.collect!(collection_id: first.id)
    assert_equal first, bullet.reload.collection

    bullet.collect!(collection_id: second.id)
    bullet.collect!(collection_id: second.id)

    assert_equal second, bullet.reload.collection
    assert_empty first.bullets
  end

  test 'a bullet cannot be assigned to another user collection' do
    other_collection = create_collection!(users(:two), name: 'Private')
    bullet = @user.bullets.new(body: 'Note', collection: other_collection)

    assert_not bullet.valid?
    assert_includes bullet.errors[:collection], 'must belong to your account'
  end

  test 'postponing into the future moves the bullet to upcoming' do
    bullet = create_bullet!(@user, body: 'Later')

    bullet.postpone!(pops_on: Date.current + 2)

    assert_not_includes Timeline.new(@user).filtered, bullet
    assert_includes @user.bullets.not_done.upcoming, bullet
  end
end
