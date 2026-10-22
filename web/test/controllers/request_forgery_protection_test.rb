# frozen_string_literal: true

require 'test_helper'

class RequestForgeryProtectionTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = false
  end

  test 'json post without Sec-Fetch-Site skips CSRF' do
    post authentication_path,
         params: { email_address: @user.email_address },
         as: :json

    assert_response :created
  end

  test 'html post without authenticity token is rejected' do
    post authentication_path, params: { email_address: @user.email_address }

    assert_response :unprocessable_entity
  end
end
