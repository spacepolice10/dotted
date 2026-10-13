# frozen_string_literal: true

require 'test_helper'

class WebhookIntakesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @webhook = @user.webhooks.create!(name: 'Zapier')
    @code = @webhook.code
  end

  test 'create lands a text on the timeline with author_name' do
    assert_difference -> { @user.bullets.count }, 1 do
      post webhook_intake_path(@code),
           params: {
             author_name: 'GitHub',
             body: 'Ship inbound webhooks'
           },
           as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal 'Ship inbound webhooks', body['body']
    assert_equal 'GitHub', body['author_name']

    bullet = @user.bullets.find(body['id'])
    assert_nil bullet.collection
    assert_equal Date.current, bullet.pops_on
    assert_equal 'GitHub', bullet.author_name
  end

  test 'create ignores a retired bulletable_type' do
    assert_difference -> { @user.bullets.count }, 1 do
      post webhook_intake_path(@code),
           params: { bulletable_type: 'Memo', body: 'Nope' },
           as: :json
    end

    assert_response :created
  end

  test 'create with unknown code returns not found' do
    post webhook_intake_path('wh_missing'),
         params: { body: 'Ghost' },
         as: :json

    assert_response :not_found
  end

  test 'create with inactive webhook returns not found' do
    @webhook.update!(active: false)

    post webhook_intake_path(@code),
         params: { body: 'Ghost' },
         as: :json

    assert_response :not_found
  end

  test 'intake does not require authentication' do
    sign_out

    post webhook_intake_path(@code),
         params: { author_name: 'CLI', body: 'Anon' },
         as: :json

    assert_response :created
  end
end
