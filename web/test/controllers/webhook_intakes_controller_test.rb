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

  test 'create keeps rich note content separate from the bullet body' do
    detail = "<h2>Build report</h2><p>#{'Detailed output ' * 1000}</p>"

    assert_difference -> { @user.bullets.count }, 1 do
      assert_difference 'Note.count', 1 do
        post webhook_intake_path(@code),
             params: { author_name: 'CI', body: 'Build finished', note: detail },
             as: :json
      end
    end

    assert_response :created
    assert_equal 'Build finished', response.parsed_body['body']
    bullet = @user.bullets.find(response.parsed_body['id'])
    assert_equal bullet, bullet.note.notable
    assert_includes bullet.note.content.body.to_html, '<h2>Build report</h2>'
    assert_includes bullet.note.content.to_plain_text, 'Detailed output ' * 1000
    assert_equal bullet_url(bullet), response.headers['Location']
  end

  test 'omitted and blank notes do not create note records' do
    assert_no_difference 'Note.count' do
      [nil, '', '   '].each do |note|
        post webhook_intake_path(@code), params: { body: 'Short summary', note: note }, as: :json
        assert_response :created
      end
    end
  end

  test 'note content does not replace the required bullet body' do
    assert_no_difference ['Bullet.count', 'Note.count'] do
      post webhook_intake_path(@code), params: { body: '', note: 'Details only' }, as: :json
    end

    assert_response :unprocessable_entity
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
