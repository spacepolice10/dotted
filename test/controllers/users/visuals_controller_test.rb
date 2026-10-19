# frozen_string_literal: true

require 'test_helper'

module Users
  class VisualsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
    end

    test 'show renders the theme form and a link back to account' do
      get user_visuals_path

      assert_response :success
      assert_select 'h1', text: 'Visuals'
      assert_select 'meta[name=turbo-cache-control][content=no-cache]'
      assert_select 'button[aria-label=?][title=?]', 'Kazakstans Skyview', 'Kazakstans Skyview'
      assert_select 'a[href=?][aria-label=?]', user_path, 'Back to Account'
      assert_select 'form[action=?]', user_visuals_path do
        assert_select 'input[name=_method][value=patch]'
        assert_select 'button[name=appearance]', count: 4
        assert_select 'button[value=default][aria-pressed=true]'
      end
    end

    test 'update persists a theme and redirects for a normal or Turbo form visit' do
      patch user_visuals_path, params: { appearance: 'kazakstans_skyview' }

      assert_response :see_other
      assert_redirected_to user_visuals_path
      assert_equal 'kazakstans_skyview', @user.reload.settings.appearance
      follow_redirect!
      assert_select 'body[data-appearance=kazakstans_skyview]'
      assert_select 'button[value=kazakstans_skyview][aria-pressed=true]'
      assert_select '.appearance-name', text: 'Kazakstans Skyview'
      assert_select '[role=status]', text: /Theme saved/, count: 0
    end

    test 'all available themes can be selected' do
      %w[default refurbished tetradka].each do |theme|
        patch user_visuals_path, params: { appearance: theme }

        assert_redirected_to user_visuals_path
        assert_equal theme, @user.reload.settings.appearance
      end
    end

    test 'invalid choices render an error without changing the saved theme' do
      @user.settings!.update!(appearance: 'refurbished')
      patch user_visuals_path, params: { appearance: 'unknown' }

      assert_response :unprocessable_entity
      assert_equal 'refurbished', @user.reload.settings.appearance
      assert_select 'body[data-appearance=refurbished]'
      assert_select 'button[value=refurbished][aria-pressed=true]'
      assert_select '[role=alert]', text: 'Choose an available theme.'
    end

    test 'update creates the settings row when missing' do
      @user.settings&.destroy!
      patch user_visuals_path, params: { appearance: 'tetradka' }

      assert_redirected_to user_visuals_path
      assert_equal 'tetradka', @user.reload.settings.appearance
    end

    test 'visual settings require authentication' do
      sign_out
      get user_visuals_path
      assert_redirected_to new_authentication_path
      patch user_visuals_path, params: { appearance: 'refurbished' }
      assert_redirected_to new_authentication_path
    end
  end
end
