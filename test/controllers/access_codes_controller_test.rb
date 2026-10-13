# frozen_string_literal: true

require 'test_helper'

class AccessCodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'create returns the code once' do
    assert_difference -> { @user.access_codes.count }, 1 do
      post access_codes_path,
           params: { access_code: { description: 'CLI' } },
           as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert body['code'].start_with?('dj_')
    assert_equal 'CLI', body['description']
    assert_nil AccessCode.find(body['id']).code
  end

  test 'index omits code and digest' do
    access_code = @user.access_codes.create!(description: 'Listed')

    get access_codes_path, as: :json

    assert_response :success
    row = response.parsed_body.find { |item| item['id'] == access_code.id }
    assert_equal access_code.code_prefix, row['code_prefix']
    assert_nil row['code']
    assert_nil row['code_digest']
  end

  test 'destroy removes the access code' do
    access_code = @user.access_codes.create!

    assert_difference -> { @user.access_codes.count }, -1 do
      delete access_code_path(access_code), as: :json
    end

    assert_response :no_content
  end

  test 'access code can create bullets' do
    sign_out
    access_code = @user.access_codes.create!
    code = access_code.code

    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: {
             bullet: {
               body: '<p>Access code note</p>',
               pops_on: Date.current.iso8601
             }
           },
           headers: { 'Authorization' => "Bearer #{code}" },
           as: :json
    end

    assert_response :created
    assert_equal 'Access code note', response.parsed_body['body']
  end
end

class AccessCodesHtmlControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'html index lists codes and links to create' do
    access_code = @user.access_codes.create!(description: 'Laptop')

    get access_codes_path

    assert_response :success
    assert_select 'main[data-size="sm"] > header h1', text: 'Access codes'
    assert_select 'nav.tabbar--back a.tabbar--back-link[href=?][aria-label=?]', search_path, 'Back', text: 'Back'
    assert_select '#access_codes.card-list article[data-elevation="2"]'
    assert_select 'form[action=?]', access_codes_path, count: 0
    assert_select 'main a[href=?][aria-label=?]', new_access_code_path, 'Create Access Code'
    assert_match access_code.code_prefix, response.body
    assert_select 'button[data-status="negative"]', text: /Revoke/
  end

  test 'html new renders the create form' do
    get new_access_code_path

    assert_response :success
    assert_select 'main[data-size="sm"] > header h1', text: 'Access code'
    assert_select 'nav.tabbar--back a.tabbar--back-link[href=?][aria-label=?]',
                  access_codes_path, 'Back to Access codes', text: 'Back'
    assert_select 'form[action=?]', access_codes_path
    assert_select 'form.form input[name="access_code[description]"]'
    assert_select 'form.form button[type="submit"][data-intent="primary"]', text: 'Create access code'
  end

  test 'html create shows the code once on index' do
    assert_difference -> { @user.access_codes.count }, 1 do
      post access_codes_path, params: { access_code: { description: 'Laptop CLI' } }
    end

    assert_redirected_to access_codes_path
    follow_redirect!

    code = @user.access_codes.order(:created_at).last
    assert_select 'article.card.card--warning[role="status"]' do
      assert_select 'strong', text: 'Access code is ready'
      assert_select 'main code', text: /\Adj_/ do |elements|
        assert_equal code.code_digest, AccessCode.digest(elements.first.text)
      end
    end
    assert_match 'Laptop CLI', response.body
    assert_equal 'no-store', response.headers['Cache-Control']
    assert_select 'meta[name="turbo-cache-control"][content="no-cache"]'

    get access_codes_path

    assert_select 'article.card[role="status"]', count: 0
    assert_no_match(/Copy this code now/, response.body)
  end

  test 'html create renders validation errors' do
    post access_codes_path, params: { access_code: { description: 'x' * 256 } }

    assert_response :unprocessable_entity
    assert_select 'form[action=?] .form--errors[role="alert"]', access_codes_path, text: /too long/
  end

  test 'html destroy revokes the access code' do
    access_code = @user.access_codes.create!(description: 'Old')

    assert_difference -> { @user.access_codes.count }, -1 do
      delete access_code_path(access_code)
    end

    assert_redirected_to access_codes_path
  end
end
