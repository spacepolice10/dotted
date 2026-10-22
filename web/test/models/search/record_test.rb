# frozen_string_literal: true

require 'test_helper'

module Search
  class RecordTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @bullet = create_bullet!(@user, body: 'Original searchable text')
      @key = { user_id: @user.id, searchable_type: 'Bullet', searchable_id: @bullet.id }
    end

    test 'search returns a lazy user scoped relation and respects its limit' do
      create_collection!(@user, name: 'Original collection')
      create_collection!(users(:two), name: 'Original collection')

      records = Search::Record.search(user: @user, search_term: 'Original', limits: 1)

      assert_kind_of ActiveRecord::Relation, records
      assert_not records.loaded?
      assert_equal 1, records.to_a.size
      assert_equal [@user.id], records.map(&:user_id)
      assert records.first.has_attribute?('fts5_rank')
    end

    test 'matching remains chainable with model scopes' do
      create_bullet!(users(:two), body: 'Original searchable text')

      records = Search::Record.where(user_id: @user.id).matching('"original"*')

      assert_equal [@bullet.id], records.pluck(:searchable_id)
    end

    test 'upsert updates the existing entry and full text index without replacing its identity' do
      record = Search::Record.find_by!(@key)
      assert Search::Record.search(user: @user, search_term: 'Original').exists?
      record.update_columns(created_at: 2.days.ago, updated_at: 1.day.ago)
      created_at = record.created_at
      updated_at = record.updated_at

      Search::Record.upsert!(@key.merge(search_name: 'Replacement', search_body: 'Newest content'))

      assert_equal record.id, Search::Record.find_by!(@key).id
      assert_equal created_at, record.reload.created_at
      assert_operator record.updated_at, :>, updated_at
      assert Search::Record.search(user: @user, search_term: 'Newest').exists?
      assert_not Search::Record.search(user: @user, search_term: 'Original').exists?
    end

    test 'competing writes for a missing index entry do not create duplicates' do
      Search::Record.where(@key).delete_all
      interleaved = false
      competing = @key.merge(search_name: 'Competing writer', search_body: '')

      # If indexing reads before inserting, let a second writer insert after
      # that SELECT has returned its empty result but before the first resumes.
      subscriber = lambda do |*, payload|
        next if interleaved || !payload[:sql].match?(/\ASELECT .*FROM "search_records"/)

        interleaved = true
        Search::Record.upsert!(competing)
      end
      ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') do
        Search::Record.upsert!(@key.merge(search_name: 'First writer', search_body: ''))
      end
      Search::Record.upsert!(competing) unless interleaved

      assert_equal 1, Search::Record.where(@key).count
    end

    test 'search repairs a partially missing set of full text triggers' do
      Search::Record.ensure_fts5_triggers!
      Search::Record.connection.execute('DROP TRIGGER search_records_au')
      Search::Record.where(@key).update_all(search_name: 'Recovered trigger', search_body: 'Repairable')

      assert Search::Record.search(user: @user, search_term: 'Repairable').exists?
      assert Search::Record.fts5_trigger_installed?
      assert_not Search::Record.search(user: @user, search_term: 'Original').exists?
    end
  end
end
