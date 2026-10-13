# frozen_string_literal: true

require 'test_helper'

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'create returns the code and intake url once' do
    assert_difference -> { @user.webhooks.count }, 1 do
      post webhooks_path,
           params: { webhook: { name: 'Zapier' } },
           as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal 'Zapier', body['name']
    assert body['code'].start_with?('wh_')
    assert_includes body['url'], "/webhooks/#{body['code']}"
    assert_nil Webhook.find(body['id']).code
  end

  test 'index omits code and digest' do
    webhook = @user.webhooks.create!(name: 'Listed')

    get webhooks_path, as: :json

    assert_response :success
    row = response.parsed_body.find { |item| item['id'] == webhook.id }
    assert_equal webhook.code_prefix, row['code_prefix']
    assert_nil row['code']
    assert_nil row['code_digest']
  end

  test 'destroy removes the webhook' do
    webhook = @user.webhooks.create!(name: 'Old')

    assert_difference -> { @user.webhooks.count }, -1 do
      delete webhook_path(webhook), as: :json
    end

    assert_response :no_content
  end

  test 'html index lists webhooks and links to create' do
    webhook = @user.webhooks.create!(name: 'Relay')

    get webhooks_path

    assert_response :success
    assert_select 'main[data-size="sm"] > header h1', text: 'Webhooks'
    assert_select 'nav.tabbar--back a.tabbar--back-link[href=?][aria-label=?]', search_path, 'Back', text: 'Back'
    assert_select 'form[action=?]', webhooks_path, count: 0
    assert_select 'main a[href=?][aria-label=?]', new_webhook_path, 'Create Webhook'
    assert_match webhook.name, response.body
    assert_match webhook.code_prefix, response.body
    assert_select 'button[data-status="negative"]', text: /Revoke/
  end

  test 'html new renders the create form and docs' do
    get new_webhook_path

    assert_response :success
    assert_select 'main[data-size="sm"] > header h1', text: 'Webhook'
    assert_select 'a[data-content="icon"][aria-label="Back to Webhooks"]', count: 0
    assert_select 'form[action=?]', webhooks_path
    assert_select 'nav.tabbar--back a.tabbar--back-link[href=?][aria-label=?]', webhooks_path, 'Back to Webhooks', text: 'Back'
    assert_select 'form.form button[type="submit"][data-intent="primary"]', text: 'Create webhook'
    assert_no_match 'bulletable_type', response.body
  end

  test 'html create shows the intake url once on index' do
    assert_difference -> { @user.webhooks.count }, 1 do
      post webhooks_path, params: { webhook: { name: 'Zapier' } }
    end

    assert_redirected_to webhooks_path
    follow_redirect!

    assert_match(/Copy this URL now/, response.body)
    assert_match(%r{/webhooks/wh_}, response.body)
    assert_match 'Zapier', response.body
    assert_select 'article.card[role="status"]' do
      assert_select 'strong', text: 'Webhook is ready'
      assert_select 'span[role="img"][aria-label=?]', 'Lightning'
      assert_select 'main code'
    end

    get webhooks_path

    assert_no_match(/Copy this URL now/, response.body)
    assert_select 'article.card[role="status"]', count: 0
  end

  test 'html destroy revokes the webhook' do
    webhook = @user.webhooks.create!(name: 'Old')

    assert_difference -> { @user.webhooks.count }, -1 do
      delete webhook_path(webhook)
    end

    assert_redirected_to webhooks_path
  end
end
