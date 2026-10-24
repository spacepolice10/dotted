# frozen_string_literal: true

require 'test_helper'
require_relative '../../test_helpers/search_index_failure_helper'

module Search
  class IndexAtomicityTest < ActiveSupport::TestCase
    include SearchIndexFailureHelper

    setup { @user = users(:one) }

    test 'failed indexing rolls back a bullet and its rich text' do
      with_search_index_failure('INSERT') do
        assert_no_difference ['Bullet.count', 'ActionText::RichText.count', 'Search::Record.count'] do
          assert_raises(ActiveRecord::StatementInvalid) do
            create_bullet!(@user, body: 'Must not be partly saved')
          end
        end
      end
    end

    test 'failed indexing rolls back edits and retains the previous search results' do
      bullet = create_bullet!(@user, body: 'Original contents')

      with_search_index_failure('INSERT') do
        assert_raises(ActiveRecord::StatementInvalid) { bullet.update!(body: 'Replacement contents') }
      end

      assert_equal 'Original contents', bullet.reload.body_as_text
      assert_equal 'Original contents', Search::Record.find_by!(searchable: bullet).search_body
      assert Search::Record.search(user: @user, search_term: 'Original').exists?
      assert_not Search::Record.search(user: @user, search_term: 'Replacement').exists?
    end

    test 'failed index removal rolls back completion and keeps recent selections' do
      bullet = create_bullet!(@user, body: 'Finish me')
      Search::Selection.record!(user: @user, searchable: bullet)

      with_search_index_failure('DELETE') do
        assert_raises(ActiveRecord::StatementInvalid) { bullet.complete! }
      end

      assert_not bullet.reload.completed?
      assert Search::Record.exists?(searchable: bullet)
      assert Search::Selection.exists?(searchable: bullet)
    end

    test 'failed index removal rolls back deletion including notes and recents' do
      bullet = create_bullet!(@user, body: 'Keep me')
      bullet.create_note!(content: 'Related rich note')
      Search::Selection.record!(user: @user, searchable: bullet)

      with_search_index_failure('DELETE') do
        assert_no_difference ['Bullet.count', 'Note.count', 'ActionText::RichText.count',
                              'Search::Selection.count', 'Search::Record.count'] do
          assert_raises(ActiveRecord::StatementInvalid) { bullet.destroy! }
        end
      end

      assert_equal 'Keep me', bullet.reload.body_as_text
      assert_equal 'Related rich note', bullet.note.content.to_plain_text
    end

    test 'failed indexing rolls back a touch' do
      bullet = create_bullet!(@user, body: 'Touch me')
      previous_time = bullet.updated_at

      with_search_index_failure('INSERT') do
        assert_raises(ActiveRecord::StatementInvalid) { bullet.touch(time: 1.hour.from_now) }
      end

      assert_equal previous_time, bullet.reload.updated_at
    end

    test 'rolling back the source also rolls back a successful index update' do
      bullet = create_bullet!(@user, body: 'Original contents')

      Bullet.transaction(requires_new: true) do
        bullet.update!(body: 'Temporary replacement')
        assert Search::Record.search(user: @user, search_term: 'Temporary').exists?
        raise ActiveRecord::Rollback
      end

      assert_equal 'Original contents', bullet.reload.body_as_text
      assert Search::Record.search(user: @user, search_term: 'Original').exists?
      assert_not Search::Record.search(user: @user, search_term: 'Temporary').exists?
    end

    test 'reindex reloads a stale instance before updating the index' do
      bullet = create_bullet!(@user, body: 'Original contents')
      stale = Bullet.find(bullet.id)
      assert_equal 'Original contents', stale.body_as_text
      bullet.update!(body: 'Current contents')

      stale.reindex

      assert_equal 'Current contents', Search::Record.find_by!(searchable: bullet).search_body
    end

    test 'failed indexing rolls back other searchable models too' do
      with_search_index_failure('INSERT') do
        assert_no_difference ['Collection.count', 'Search::Record.count'] do
          assert_raises(ActiveRecord::StatementInvalid) { create_collection!(@user, name: 'Not saved') }
        end
      end
    end
  end
end
