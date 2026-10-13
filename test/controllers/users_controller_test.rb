# frozen_string_literal: true

require 'test_helper'

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'show renders account page with sign out' do
    get user_path

    assert_response :success
    assert_select 'main[data-size="sm"] h1', text: 'Account'
    assert_select 'main p', text: @user.email_address
    assert_select 'a[href=?]', access_codes_path, text: /Access codes/
    assert_select 'a[href=?]', webhooks_path, text: /Webhooks/
    assert_select 'form[action=?][data-turbo-confirm=?]', authentication_path, 'Sign out of Dotted?'
    assert_select 'button', text: /Sign out/
  end

  test 'mobile account page keeps the user tab selected' do
    get user_path, headers: { 'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)' }

    assert_response :success
    assert_tabbar_link user_path, label: 'User', active: true
    assert_select 'nav.tabbar--navigation span.tabbar--item-active[aria-current=page]', text: 'User'
    assert_select 'nav.tabbar--navigation a[href=?]', user_path, count: 0
  end

  test 'show requires authentication' do
    sign_out

    get user_path

    assert_redirected_to new_authentication_path
  end
end
