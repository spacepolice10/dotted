# frozen_string_literal: true

require "test_helper"

class SearchReindexJobTest < ActiveSupport::TestCase
  test "rebuilds search records for searchable models" do
    user = users(:one)
    collection = create_collection!(user, name: "reindex me")
    Search::Record.delete_all

    SearchReindexJob.perform_now

    record = Search::Record.find_by(searchable: collection)

    assert record
    assert_equal "reindex me", record.search_name
  end
end
