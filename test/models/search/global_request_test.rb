# frozen_string_literal: true

require "test_helper"

class Search::GlobalRequestTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "returns empty entries for blank query" do
    create_collection!(@user, name: "alpha")

    entries = Search::GlobalRequest.call(user: @user, query: "")

    assert_empty entries
  end

  test "scopes results to the current user" do
    other_user = users(:two)
    create_collection!(@user, name: "mine")
    create_collection!(other_user, name: "mine")

    entries = Search::GlobalRequest.call(user: @user, query: "mine")

    assert_equal 1, entries.size
    assert_equal "Collection", entries.first.class.name
    assert_equal @user.id, entries.first.user_id
  end

  test "finds collections by name" do
    create_collection!(@user, name: "alex")

    entries = Search::GlobalRequest.call(user: @user, query: "alex")

    assert_equal 1, entries.size
    assert_equal "Collection", entries.first.class.name
    assert_equal "alex", entries.first.name
  end

  test "applies fuzzy fallback for near matches" do
    create_collection!(@user, name: "alpha")

    entries = Search::GlobalRequest.call(user: @user, query: "alpa")

    assert_equal 1, entries.size
    assert_equal "alpha", entries.first.name
  end

  test "returns a flat ranked list across entity types" do
    create_collection!(@user, name: "alpha reading")
    create_bullet!(@user, body: "alpha task")

    entries = Search::GlobalRequest.call(user: @user, query: "alpha")

    assert_equal 2, entries.size
    assert_includes entries.map { |entry| entry.class.name }, "Collection"
    assert_includes entries.map { |entry| entry.class.name }, "Bullet"
  end
end
