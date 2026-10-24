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

  test 'cookie-free json authentication without Sec-Fetch-Site skips CSRF' do
    post authentication_path,
         params: { email_address: @user.email_address },
         as: :json

    assert_response :created
  end

  test 'cookie-authenticated json post without a CSRF token is rejected' do
    sign_in_as @user

    assert_no_difference 'Collection.count' do
      post collections_path, params: { collection: { name: 'Forged' } }, as: :json
    end

    assert_response :unprocessable_entity
  end

  test 'cookie-free bearer json post without a CSRF token is allowed' do
    access_code = @user.access_codes.create!(description: 'CLI')

    assert_difference 'Collection.count', 1 do
      post collections_path,
           params: { collection: { name: 'CLI collection' } },
           headers: { 'Authorization' => "Bearer #{access_code.code}" },
           as: :json
    end

    assert_response :created
  end

  test 'html post without authenticity token is rejected' do
    post authentication_path, params: { email_address: @user.email_address }

    assert_response :unprocessable_entity
  end
end
