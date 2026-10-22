# frozen_string_literal: true

require 'test_helper'

class WebhookTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'create issues a wh_ code and digests it' do
    webhook = @user.webhooks.create!(name: 'Zapier')

    assert webhook.code.start_with?('wh_')
    assert_equal webhook.code_prefix, webhook.code.first(8)
    assert_equal Webhook.digest(webhook.code), webhook.code_digest
  end

  test 'authenticate finds active webhook by code' do
    webhook = @user.webhooks.create!(name: 'Zapier')
    raw = webhook.code

    assert_equal webhook, Webhook.authenticate(raw)
    webhook.update!(active: false)
    assert_nil Webhook.authenticate(raw)
  end

  test 'create_bullet! lands text on the timeline' do
    webhook = @user.webhooks.create!(name: 'Zapier')

    bullet = webhook.create_bullet!(
      author_name: 'Zapier',
      body: 'From outside'
    )

    assert_equal @user, bullet.user
    assert_equal 'Zapier', bullet.author_name
    assert_equal 'From outside', bullet.body_as_text
    assert_equal Date.current, bullet.pops_on
  end
end
