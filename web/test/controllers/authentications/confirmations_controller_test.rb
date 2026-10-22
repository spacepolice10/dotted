# frozen_string_literal: true

require 'test_helper'

module Authentications
  class ConfirmationsControllerTest < ActionDispatch::IntegrationTest
    setup { @user = users(:one) }

    test 'new with login_email in session shows form' do
      request_login_code(@user.email_address)
      get new_authentication_confirmation_path

      assert_response :success
      assert_select 'header.header', count: 0
      assert_select 'h1.branding-heading', text: 'dotted', count: 1
      assert_select 'h2', text: 'Check your email', count: 1
      assert_select 'form[action=?]', authentication_confirmation_path
    end

    test 'new without login_email redirects to authentication' do
      get new_authentication_confirmation_path

      assert_redirected_to new_authentication_path
    end

    test 'create with valid code starts session' do
      code = request_login_code(@user.email_address)
      confirm_login_code(code)

      assert_redirected_to root_path
      assert cookies[:session_id]
    end

    test 'create with valid lowercase code starts session' do
      code = request_login_code(@user.email_address)
      confirm_login_code(code.downcase)

      assert_redirected_to root_path
      assert cookies[:session_id]
    end

    test 'create with invalid code rejects' do
      request_login_code(@user.email_address)
      confirm_login_code('WRONG1')

      assert_redirected_to new_authentication_confirmation_path
      assert_nil cookies[:session_id]
      follow_redirect!
      assert_select '#toasts .toasts--errmsg', text: /Invalid or expired code/
    end

    test 'create with expired code rejects' do
      code = request_login_code(@user.email_address)
      @user.auth_codes.last.update!(expires_at: 1.minute.ago)
      confirm_login_code(code)

      assert_redirected_to new_authentication_confirmation_path
      assert_nil cookies[:session_id]
    end

    test 'create destroys all user login codes on success' do
      code = request_login_code(@user.email_address)
      assert_equal 1, @user.auth_codes.count

      confirm_login_code(code)

      assert_equal 0, @user.auth_codes.count
    end

    test 'create json with valid code returns session code' do
      auth = request_login_code_json(@user.email_address)

      confirm_login_code_json(
        code: auth[:code],
        pending_authentication_code: auth[:pending_authentication_code]
      )

      assert_response :success
      body = response.parsed_body
      assert body['session_code'].present?
      assert_not body.key?('onboarded')
      assert cookies[:session_id].present?
    end

    test 'create json with invalid code returns unauthorized' do
      auth = request_login_code_json(@user.email_address)

      confirm_login_code_json(
        code: 'WRONG1',
        pending_authentication_code: auth[:pending_authentication_code]
      )

      assert_response :unauthorized
    end

    test 'create json with missing pending code returns unauthorized' do
      request_login_code_json(@user.email_address)
      cookies.delete(:pending_authentication_code)

      post authentication_confirmation_path, params: { code: 'ABCDEF' }, as: :json

      assert_response :unauthorized
    end
  end
end
