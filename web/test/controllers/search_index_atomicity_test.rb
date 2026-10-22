# frozen_string_literal: true

require 'test_helper'
require_relative '../test_helpers/search_index_failure_helper'

class SearchIndexAtomicityTest < ActionDispatch::IntegrationTest
  include SearchIndexFailureHelper

  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'creation fails without saving a bullet when its index cannot be written' do
    with_search_index_failure('INSERT') do
      assert_no_difference ['Bullet.count', 'ActionText::RichText.count', 'Search::Record.count'] do
        assert_raises(ActiveRecord::StatementInvalid) do
          post bullets_path, params: { bullet: { body: 'All or nothing' } }, as: :json
        end
      end
    end

    post bullets_path, params: { bullet: { body: 'All or nothing' } }, as: :json

    assert_response :created
    assert Search::Record.search(user: @user, search_term: 'nothing').exists?
  end

  test 'editing fails without saving a new version when indexing fails' do
    bullet = create_bullet!(@user, body: 'Original version')

    with_search_index_failure('INSERT') do
      assert_raises(ActiveRecord::StatementInvalid) do
        patch bullet_path(bullet), params: { bullet: { body: 'Rejected version' } }, as: :json
      end
    end

    assert_equal 'Original version', bullet.reload.body_as_text
    assert_equal 'Original version', Search::Record.find_by!(searchable: bullet).search_body
  end
end
