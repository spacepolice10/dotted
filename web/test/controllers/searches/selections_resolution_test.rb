# frozen_string_literal: true

require 'test_helper'

module Searches
  # The controller must resolve a searchable without a hand-maintained whitelist.
  class SelectionsResolutionTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @other_user = users(:two)
      sign_in_as @user
      @collection = create_collection!(@user, name: 'alpha')
    end

    test "create records a selection without a query param" do
      assert_difference -> { @user.search_selections.count }, 1 do
        post search_selection_path,
             params: { searchable_type: "Collection", searchable_id: @collection.id },
             as: :json
      end

      assert_response :no_content
      assert_equal @collection, @user.search_selections.sole.searchable
    end

    test "create rejects a type that is not searchable" do
      post search_selection_path,
           params: { searchable_type: "User", searchable_id: @user.id },
           as: :json

      assert_response :not_found
      assert_empty @user.search_selections
    end

    test "create rejects another users entity" do
      other = create_collection!(@other_user, name: "secret")

      post search_selection_path,
           params: { searchable_type: "Collection", searchable_id: other.id },
           as: :json

      assert_response :not_found
      assert_empty @user.search_selections
    end

    test "create rejects an id that matches no record" do
      post search_selection_path,
           params: { searchable_type: "Collection", searchable_id: 0 },
           as: :json

      assert_response :not_found
      assert_empty @user.search_selections
    end

    test "create routes on type even when ids collide across tables" do
      bullet = create_bullet!(@user, body: "Buy milk")

      post search_selection_path,
           params: { searchable_type: "Bullet", searchable_id: bullet.id },
           as: :json

      assert_response :no_content
      # ids collide across bullets and collections, so the type is what
      # decides which record this is.
      assert_equal bullet, @user.search_selections.sole.searchable
    end
  end
end