# frozen_string_literal: true

require 'test_helper'

class JsonApiTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'bullet show update and delete return JSON responses' do
    bullet = create_bullet!(@user, body: 'Original')

    get bullet_path(bullet), as: :json
    assert_response :success
    assert_equal bullet.id, response.parsed_body['id']

    patch bullet_path(bullet), params: { bullet: { body: 'Changed' } }, as: :json
    assert_response :success
    assert_equal 'Changed', response.parsed_body['body']

    patch bullet_path(bullet), params: { bullet: { body: '' } }, as: :json
    assert_response :unprocessable_entity
    assert response.parsed_body.key?('base')

    delete bullet_path(bullet), as: :json
    assert_response :no_content
    assert_not @user.bullets.exists?(bullet.id)
  end

  test 'collections can be listed created updated and deleted as JSON' do
    post collections_path, params: { collection: { name: 'Ideas' } }, as: :json
    assert_response :created
    id = response.parsed_body.fetch('id')
    assert_equal 'ideas', response.parsed_body['name']
    assert_equal collection_url(id), response.headers['Location']

    get collections_path, as: :json
    assert_response :success
    assert_includes response.parsed_body.map { |item| item['id'] }, id

    get collection_path(id), as: :json
    assert_response :success
    assert_equal id, response.parsed_body['id']

    patch collection_path(id), params: { collection: { description: 'A place for ideas' } }, as: :json
    assert_response :success
    assert_equal 'A place for ideas', response.parsed_body['description']

    patch collection_path(id), params: { collection: { name: '' } }, as: :json
    assert_response :unprocessable_entity
    assert response.parsed_body.key?('name')

    delete collection_path(id), as: :json
    assert_response :no_content
    assert_not @user.collections.exists?(id)
  end

  test 'search results return matching records as JSON' do
    bullet = create_bullet!(@user, body: 'Unique silver comet')
    create_bullet!(users(:two), body: 'Unique silver comet private')

    get search_results_path(q: 'silver comet'), as: :json
    assert_response :success
    assert_includes response.parsed_body.map { |entry| entry['id'] }, bullet.id
    assert response.parsed_body.all? { |entry| entry['url'].present? }
    assert response.parsed_body.none? { |entry| entry['name'].include?('private') }
  end

  test 'bulk JSON actions return updated bullets and report invalid date' do
    bullet = create_bullet!(@user, body: 'Bulk item')
    ids = bullet.id.to_s

    post completion_path, params: { bullet_ids: ids }, as: :json
    assert_response :success
    assert_equal true, response.parsed_body.first['done']

    delete completion_path, params: { bullet_ids: ids }, as: :json
    assert_response :success
    assert_equal false, response.parsed_body.first['done']

    post postpone_path, params: { bullet_ids: ids, pops_on: 'invalid' }, as: :json
    assert_response :unprocessable_entity
    assert response.parsed_body.key?('pops_on')

    post postpone_path, params: { bullet_ids: ids, pops_on: 2.days.from_now.to_date.iso8601 }, as: :json
    assert_response :success
    assert_equal bullet.reload.pops_on.iso8601, response.parsed_body.first['pops_on']

    collection = create_collection!(@user, name: 'Group')
    post collect_path, params: { bullet_ids: ids, collection_id: collection.id }, as: :json
    assert_response :success
    assert_equal collection.id, response.parsed_body.first['collection_id']

    post publish_path, params: { bullet_ids: ids }, as: :json
    assert_response :success
    assert bullet.reload.published?
    assert_equal published_url(bullet.public_code), response.parsed_body.first['public_url']

    get published_index_path, as: :json
    assert_response :success
    assert_includes response.parsed_body.map { |item| item['id'] }, bullet.id

    delete publish_path, params: { bullet_ids: ids }, as: :json
    assert_response :success
    assert_not bullet.reload.published?
  end

  test 'attachment JSON is scoped to the signed-in user' do
    owned = create_file_bullet!(@user, filename: 'owned.pdf').file.blob
    foreign = create_file_bullet!(users(:two), filename: 'foreign.pdf').file.blob

    get attachments_path, as: :json
    assert_response :success
    assert_includes response.parsed_body.map { |item| item['filename'] }, 'owned.pdf'
    assert_not_includes response.parsed_body.map { |item| item['filename'] }, 'foreign.pdf'

    get attachment_path(owned.signed_id), as: :json
    assert_response :success
    assert_equal owned.signed_id, response.parsed_body['signed_id']
    assert response.parsed_body['download_url'].present?

    get attachment_path(foreign.signed_id), as: :json
    assert_response :not_found
  end

  test 'access code can use new JSON routes without a browser session' do
    bullet = create_bullet!(@user, body: 'CLI bullet')
    access_code = @user.access_codes.create!(description: 'CLI')
    bearer = access_code.code
    sign_out

    get bullet_path(bullet), headers: { 'Authorization' => "Bearer #{bearer}" }, as: :json
    assert_response :success
    assert_equal bullet.id, response.parsed_body['id']

    post collections_path,
         params: { collection: { name: 'CLI collection' } },
         headers: { 'Authorization' => "Bearer #{bearer}" },
         as: :json
    assert_response :created
    assert_equal 'cli collection', response.parsed_body['name']

    get bullet_path(bullet), as: :json
    assert_response :unauthorized
  end
end
