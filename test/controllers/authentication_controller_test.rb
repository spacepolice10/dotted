# frozen_string_literal: true

require 'test_helper'

class AuthenticationControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test 'new' do
    get new_authentication_path

    assert_response :success
    assert_select 'header.header', count: 0
    assert_select 'h1.branding-heading', text: 'dotted', count: 1
    assert_select 'h2', text: 'Sign in', count: 1
    assert_select 'form[action=?][data-controller=?]', authentication_path, 'valid-email'
    assert_select 'input[type=email][data-valid-email-target=?]', 'input'
    assert_select 'a[href=?]', features_path, text: /Features/
    assert_select 'a[href=?]', support_path, text: /Support/
  end

  test 'create with known email sends code and redirects to confirmation page' do
    post authentication_path, params: { email_address: @user.email_address }

    assert_redirected_to new_authentication_confirmation_path
    assert_equal @user.email_address, session[:login_email]
    assert_enqueued_emails 1
  end

  test 'create with new email creates user, sends code, and redirects' do
    assert_difference 'User.count', 1 do
      assert_enqueued_emails 1 do
        post authentication_path, params: { email_address: 'newuser@example.com' }
      end
    end

    assert_redirected_to new_authentication_confirmation_path
    assert_equal 'newuser@example.com', session[:login_email]
  end

  test 'create with invalid email rerenders form' do
    assert_no_difference 'User.count' do
      post authentication_path, params: { email_address: 'not-an-email' }
    end

    assert_response :unprocessable_entity
    assert_select 'form[action=?]', authentication_path
  end

  test 'destroy' do
    sign_in_as(@user)

    delete authentication_path

    assert_redirected_to new_authentication_path
    assert_empty cookies[:session_id]
  end

  test 'create json returns pending authentication code' do
    post authentication_path, params: { email_address: @user.email_address }, as: :json

    assert_response :created
    assert response.parsed_body['pending_authentication_code'].present?
    assert cookies[:pending_authentication_code].present?
    assert_enqueued_emails 1
  end

  test 'create json with invalid email returns 422' do
    post authentication_path, params: { email_address: 'not-an-email' }, as: :json

    assert_response :unprocessable_entity
    assert response.parsed_body['email_address'].present?
  end

  test 'destroy json returns no content' do
    sign_in_as(@user)

    delete authentication_path, as: :json

    assert_response :no_content
    assert_empty cookies[:session_id]
  end
end
