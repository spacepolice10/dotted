# frozen_string_literal: true

require 'test_helper'

module Home
  class AppearancesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @user.create_settings! unless @user.settings
      sign_in_as @user
    end

    test 'update persists a known appearance' do
      post search_appearance_path, params: { appearance: 'warm' }, as: :json

      assert_response :ok
      assert_equal 'warm', @user.reload.settings.appearance
    end

    test 'update rejects an unknown appearance' do
      post search_appearance_path, params: { appearance: 'unknown' }, as: :json

      assert_response :unprocessable_entity
      assert_equal 'default', @user.reload.settings.appearance
    end

    test 'update creates the settings row when missing' do
      @user.settings.destroy!

      post search_appearance_path, params: { appearance: 'cool' }, as: :json

      assert_response :ok
      assert_equal 'cool', @user.reload.settings.appearance
    end
  end
end
