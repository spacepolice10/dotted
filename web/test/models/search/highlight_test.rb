# frozen_string_literal: true

require 'test_helper'

class Search::HighlightTest < ActiveSupport::TestCase
  test 'marks a prefix match and keeps the rest of the word' do
    html = Search::Highlight.call('<p>Buy <strong>milk</strong> today</p>', 'mil')

    assert_includes html, '<strong><mark class="search--term decoration--circle decoration-colour--sky">milk</mark></strong>'
    assert_includes html, 'Buy '
    assert_includes html, ' today'
  end

  test 'does not mark a match inside a word or an attribute' do
    html = Search::Highlight.call('<a href="https://example.com/milk">fresh</a>', 'ilk')

    assert_equal '<a href="https://example.com/milk">fresh</a>', html
  end

  test 'marks the visible word and leaves the url alone' do
    html = Search::Highlight.call('<a href="https://example.com/milk">milk</a>', 'milk')

    assert_includes html, 'href="https://example.com/milk"'
    assert_includes html, '<mark class="search--term decoration--circle decoration-colour--sky">milk</mark>'
  end

  test 'marks each term and keeps the original case' do
    html = Search::Highlight.call('<p>Buy MILK now</p>', 'buy milk')

    assert_includes html, '<mark class="search--term decoration--circle decoration-colour--sky">Buy</mark>'
    assert_includes html, '<mark class="search--term decoration--circle decoration-colour--sky">MILK</mark>'
  end

  test 'marks a unicode prefix' do
    html = Search::Highlight.call('<p>молоко</p>', 'мол')

    assert_includes html, '<mark class="search--term decoration--circle decoration-colour--sky">молоко</mark>'
  end

  test 'returns the original html when nothing matches' do
    html = '<p>Call mom</p>'.html_safe

    assert_same html, Search::Highlight.call(html, 'zzz')
  end
end
