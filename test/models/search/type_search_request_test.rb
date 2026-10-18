# frozen_string_literal: true

require 'test_helper'

module Search
  class TypeSearchRequestTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
    end

    test 'finds missing extra and substituted letters including the first letter' do
      collection = create_collection!(@user, name: 'groceries')

      %w[groceris grooceries groceriez roceries xgroceries xroceries].each do |search_term|
        assert_includes search(search_term), collection, "Expected #{search_term} to find groceries"
      end
    end

    test 'finds adjacent letter swaps at the start middle and end of a word' do
      collection = create_collection!(@user, name: 'Ruby')

      %w[uRby Rbuy Ruyb].each do |search_term|
        assert_includes search(search_term), collection, "Expected #{search_term} to find Ruby"
      end
      assert_empty search('ybur')
    end

    test 'combines a letter swap with a correction in another search term term' do
      bullet = create_bullet!(@user, body: 'Ruby notebook')

      assert_equal [bullet], search('Rbuy notebok')
    end

    test 'finds adjacent swaps in non Latin words' do
      bullet = create_bullet!(@user, body: 'Купить молоко')

      assert_includes search('млооко'), bullet
    end

    test 'finds a typo near the end of a long note body' do
      bullet = create_bullet!(@user, body: "#{'ordinary text ' * 1800} groceries")

      assert_includes search('groceris'), bullet
    end

    test 'does not stop at the first two hundred records' do
      now = Time.current
      Search::Record.insert_all!(201.times.map do |index|
        { user_id: @user.id, searchable_type: 'Bullet', searchable_id: -index - 1,
          search_name: 'Unrelated', search_body: '', created_at: now, updated_at: now }
      end)
      collection = create_collection!(@user, name: 'groceries')

      assert_includes search('groceris'), collection
    end

    test 'all corrected terms must match the same record' do
      matching = create_bullet!(@user, body: 'Buy groceries tomorrow')
      create_bullet!(@user, body: 'Buy groceries today')
      create_bullet!(@user, body: 'Telephone tomorrow')

      assert_equal [matching], search('groceris tomorow')
    end

    test 'keeps prefix matching alongside corrected terms' do
      bullet = create_bullet!(@user, body: 'Groceries tomorrow')

      assert_includes search('groceris tom'), bullet
    end

    test 'does not correct very short terms or two letter mistakes' do
      create_collection!(@user, name: 'cat groceries')

      assert_empty search('ct')
      assert_empty search('grocriz')
    end

    test 'supports non Latin letters and punctuation in bodies' do
      bullet = create_bullet!(@user, body: 'Купить молоко, пожалуйста!')

      assert_includes search('молко'), bullet
    end

    test 'other users corrections cannot crowd out the users own words' do
      other_user = users(:two)
      ('a'..'t').each { |letter| create_collection!(other_user, name: "#{letter}roceries") }
      own = create_collection!(@user, name: 'zroceries')

      assert_equal [own], search('xroceries')
    end

    test 'uses the same Latin accent folding as full text search' do
      collection = create_collection!(@user, name: 'Café')

      assert_includes search('caffé'), collection
    end

    test 'long queries and long words retain ordinary exact search' do
      name = 'one two three four five six seven eight nine'
      collection = create_collection!(@user, name:)
      assert_includes search(name), collection

      long_name = 'a' * 40
      collection = create_collection!(@user, name: long_name)
      assert_includes search(long_name), collection
      assert_empty search("#{long_name}b")
    end

    test 'vocabulary reflects edits and deletions without a separate rebuild' do
      collection = create_collection!(@user, name: 'groceries')
      assert_includes search('groceris'), collection

      collection.update!(name: 'shopping')
      assert_empty search('groceris')
      assert_includes search('shoping'), collection

      collection.destroy!
      assert_empty search('shoping')
    end

    test 'punctuation only search term returns no results' do
      assert_empty search('"?!')
    end

    private

    def search(search_term)
      Search::GlobalRequest.call(user: @user, search_term:)
    end
  end
end
