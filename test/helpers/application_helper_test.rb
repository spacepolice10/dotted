# frozen_string_literal: true

require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper
  include IconHelper

  test 'highlight_search_result drops inner links so the row link stays valid' do
    html = highlight_search_result('<p>See <a href="https://example.com">milk</a> today</p>', 'milk')

    assert_includes html, '<mark class="search--term decoration--circle decoration-colour--sky">milk</mark>'
    assert_not_includes html, '<a'
    assert_not_includes html, 'href'
    assert_includes html, 'See '
    assert_includes html, ' today'
  end

  test 'highlight_search_result keeps formatting tags around the marked term' do
    html = highlight_search_result('<p>Buy <strong>milk</strong></p>', 'milk')

    assert_includes html, '<strong><mark class="search--term decoration--circle decoration-colour--sky">milk</mark></strong>'
  end

  test 'highlight_search_result returns the original html when nothing matches' do
    html = '<p>Call mom</p>'.html_safe

    assert_same html, highlight_search_result(html, 'zzz')
  end

  test 'search_results_count marks a full page as a lower bound' do
    assert_equal '1 result', search_results_count(1)
    assert_equal '2 results', search_results_count(2)
    assert_equal "#{Search::GlobalRequest::LIMIT}+ results", search_results_count(Search::GlobalRequest::LIMIT)
  end

  test 'back_link_to renders fallback href and navigation data' do
    html = back_link_to(search_path, class: 'button--tertiary button--sm') do
      safe_join([icon('arrow-left'), ' Back'])
    end

    assert_includes html, %(href="#{search_path}")
    assert_includes html, 'class="button--tertiary button--sm"'
    assert_includes html, 'data-controller="navigation"'
    assert_match(/data-action="[^"]*click-&gt;navigation#back/, html)
    assert_includes html, 'arrow-left'
    assert_includes html, 'Back'
  end

  test 'back_link_to merges existing data controller and action' do
    html = back_link_to(
      collections_path,
      data: { controller: 'hotkey', action: 'keydown.esc@document->hotkey#click', turbo_frame: '_top' }
    ) { 'Back' }

    assert_includes html, %(href="#{collections_path}")
    assert_includes html, 'data-controller="hotkey navigation"'
    assert_match(/keydown\.esc@document-&gt;hotkey#click/, html)
    assert_match(/click-&gt;navigation#back/, html)
    assert_includes html, 'data-turbo-frame="_top"'
  end
end
