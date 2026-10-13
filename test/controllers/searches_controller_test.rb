# frozen_string_literal: true

require 'test_helper'

class SearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  # --- /search : navigation only ---

  test 'show renders search-navigation' do
    get search_path

    assert_response :success
    assert_select 'main#search > section > header h1', text: 'Index'
    assert_select 'article.search--navigation'
    assert_select 'ul#search_collections[data-layout=grid]'
    assert_select 'article.search--navigation a[href=?]', bullets_path(from: Date.current + 1), text: 'Upcoming'
  end

  test 'show opens the search dialog instead of linking away' do
    get search_path

    assert_response :success
    assert_select 'button[commandfor=search_picker_dialog][command=show-modal][aria-label=Search]'
    assert_select 'dialog#search_picker_dialog'
    assert_select 'dialog#search_picker_dialog form[action=?][method=get]', search_results_path
    assert_select 'dialog#search_picker_dialog input[type=search][name=q]'
  end

  test 'dialog picker autofocuses on desktop but not on mobile' do
    get search_path
    assert_select 'dialog#search_picker_dialog input[name=q][autofocus]', count: 1

    get search_path, headers: { 'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)' }

    assert_response :success
    assert_select 'dialog#search_picker_dialog input[name=q]', count: 1
    assert_select 'dialog#search_picker_dialog input[name=q][autofocus]', count: 0
  end

  test 'show preloads the dialog empty, even with a query' do
    create_bullet!(@user, body: 'Buy milk today')

    get search_path, params: { q: 'milk' }

    assert_response :success
    assert_select 'a.combobox--item', count: 0
    assert_select 'dialog#search_picker_dialog .empty-state h2', text: 'No results'
    assert_select 'article.search--navigation a.combobox--item', count: 0
    assert_select 'article.search--navigation', count: 1
  end

  test 'show ignores the recent param' do
    collection = create_collection!(@user, name: 'recent alpha')
    Search::Selection.record!(user: @user, searchable: collection)

    get search_path, params: { recent: '1' }

    assert_response :success
    assert_select 'article.search--navigation a.combobox--item', count: 0
    assert_select 'dialog#search_picker_dialog a.combobox--item[href=?]', collection_path(collection)
  end

  test 'mobile search keeps the three item tabbar' do
    get search_path, headers: { 'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)' }

    assert_response :success
    assert_select 'nav.tabbar--back', count: 0
    assert_select 'nav.tabbar--navigation a.tabbar--item', count: 2
    assert_select 'nav.tabbar--navigation span.tabbar--item-active[aria-current=page]', text: 'Index'
    assert_select 'nav.tabbar--navigation a[href=?]', search_path, count: 0
  end

  test 'desktop search page shows the three item tabbar' do
    get search_path

    assert_select 'nav.tabbar--navigation a.tabbar--item', count: 2
    assert_select 'nav.tabbar--navigation span.tabbar--item-active[aria-current=page]', text: 'Index'
    assert_select 'nav.tabbar--navigation a[href=?]', search_path, count: 0
  end

  # --- /search/results : the search page ---

  test 'results renders the search form wired to the results route' do
    get search_results_path

    assert_response :success
    assert_select 'main.search--window[data-controller=search]'
    assert_select 'main.search--window[data-search-path-value=?]', search_results_path
    assert_select 'form[action=?][method=get]', search_results_path
    assert_select 'input.search--textform[type=search][name=q]'
    assert_select 'button.search--cleanup[aria-label=?]', 'Clear search'
    assert_select '.search--navigation', count: 0
  end

  test 'results preloads the global palette with the command-k trigger' do
    get search_results_path

    assert_response :success
    assert_select 'button[commandfor=search_picker_dialog][command=show-modal][aria-label=?]', 'Open search'
    assert_select 'dialog#search_picker_dialog form[action=?][method=get]', search_results_path
    assert_select 'dialog#search_picker_dialog input[type=search][name=q]'
  end
  test 'results excludes completed bullets' do
    matching = create_bullet!(@user, body: 'Buy milk today')
    matching.complete!

    get search_results_path, params: { q: 'milk' }

    assert_response :success
    assert_empty @controller.instance_variable_get(:@entries)
  end

  test 'results answers turbo-stream for the dialog picker' do
    matching = create_bullet!(@user, body: 'Buy milk today')

    get search_results_path, params: { q: 'milk' }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_select 'turbo-stream[action=update][target=search_section] a.combobox--item[href=?]',
                  bullet_path(matching)
    assert_select 'turbo-stream[action=update][target=search_dialog_results] a.combobox--item[href=?]',
                  bullet_path(matching)
  end

  test 'results wraps the results list in the section frame' do
    get search_results_path

    assert_response :success
    assert_select 'turbo-frame#search_section.search--section ul[role=listbox]'
    assert_select 'turbo-frame#search_section .empty-state h2', text: 'No results'
  end

  test 'results loads ranked entries for the backend' do
    matching = create_bullet!(@user, body: 'Buy milk today')
    create_bullet!(@user, body: 'Call mom tonight')

    get search_results_path, params: { q: 'milk' }

    assert_response :success
    controller = @controller
    assert_equal 'milk', controller.instance_variable_get(:@q)
    assert_includes controller.instance_variable_get(:@entries).map(&:id), matching.id
    assert_select 'turbo-frame#search_section ul[role=listbox] a.combobox--item'
    assert_select 'article.search--navigation', count: 0
  end

  test 'results caps query results at ten' do
    12.times { |i| create_collection!(@user, name: "indexed collection #{i}") }

    get search_results_path, params: { q: 'indexed collection' }

    assert_response :success
    assert_equal 10, @controller.instance_variable_get(:@entries).size
  end

  test 'results marks the matching term inside the bullet body' do
    create_bullet!(@user, body: 'Buy milk today')

    get search_results_path, params: { q: 'milk' }

    assert_response :success
    assert_select 'turbo-frame#search_section mark.search--term', text: 'milk'
  end

  test 'results keeps formatting tags around the marked term' do
    create_bullet!(@user, body: 'Buy <strong>milk</strong> today')

    get search_results_path, params: { q: 'milk' }

    assert_response :success
    assert_select 'turbo-frame#search_section strong > mark.search--term', text: 'milk'
  end

  test 'results marks a term that only appears below the first line' do
    create_bullet!(@user, body: 'Buy milk<p>and fresh bread</p>')

    get search_results_path, params: { q: 'bread' }

    assert_response :success
    assert_select 'turbo-frame#search_section mark.search--term', text: 'bread'
  end

  test 'results derives each result path polymorphically' do
    bullet = create_bullet!(@user, body: 'Buy milk today')
    collection = create_collection!(@user, name: 'milk')

    get search_results_path, params: { q: 'milk' }

    assert_response :success
    assert_select 'turbo-frame#search_section a.combobox--item[href=?]', bullet_path(bullet)
    assert_select 'turbo-frame#search_section a.combobox--item[href=?]', collection_path(collection)
  end

  test 'results links a collection result and marks its name' do
    collection = create_collection!(@user, name: 'milk')

    get search_results_path, params: { q: 'milk' }

    assert_response :success
    assert_select 'turbo-frame#search_section a.combobox--item[href=?]', collection_path(collection)
    assert_select 'turbo-frame#search_section .search--result-body', text: 'milk'
    assert_select 'turbo-frame#search_section mark.search--term', text: 'milk'
  end

  test 'results does not nest links inside a bullet body' do
    create_bullet!(@user, body: 'See <a href="https://example.com">milk</a> today')

    get search_results_path, params: { q: 'milk' }

    assert_response :success
    assert_select 'turbo-frame#search_section a.combobox--item a', count: 0
    assert_select 'turbo-frame#search_section mark.search--term', text: 'milk'
  end

  test 'results reports no results for a blank query' do
    get search_results_path, params: { q: '   ' }

    assert_response :success
    assert_equal '', @controller.instance_variable_get(:@q)
    assert_empty @controller.instance_variable_get(:@entries)
    assert_select 'turbo-frame#search_section .empty-state h2', text: 'No results'
  end

  test 'results frame request returns the section frame for the query' do
    matching = create_bullet!(@user, body: 'Buy milk today')

    get search_results_path, params: { q: 'milk' }, headers: { 'Turbo-Frame' => 'search_section' }

    assert_response :success
    assert_select 'turbo-frame#search_section ul[role=listbox]'
    assert_select 'turbo-frame#search_section a.combobox--item[href=?]', bullet_path(matching)
  end

  test 'results keeps the search tab active in the tabbar' do
    get search_results_path

    assert_select 'nav.tabbar--navigation span.tabbar--item-active[aria-current=page]', text: 'Index'
    assert_select 'nav.tabbar--navigation a[href=?]', search_path, count: 0
  end

  test 'results shows recent selections for a blank query' do
    collection = create_collection!(@user, name: 'recent alpha')
    Search::Selection.record!(user: @user, searchable: collection)

    get search_results_path

    assert_response :success
    assert_select 'turbo-frame#search_section a.combobox--item[href=?]', collection_path(collection)
  end

  test 'results turbo-stream shows recent selections for a blank query' do
    collection = create_collection!(@user, name: 'recent alpha')
    Search::Selection.record!(user: @user, searchable: collection)

    get search_results_path, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_select 'turbo-stream[action=update][target=search_section] a.combobox--item[href=?]',
                  collection_path(collection)
    assert_select 'turbo-stream[action=update][target=search_dialog_results] a.combobox--item[href=?]',
                  collection_path(collection)
  end

  test 'results link records the search via the recent-search controller' do
    bullet = create_bullet!(@user, body: 'Buy milk today')

    get search_results_path, params: { q: 'milk' }

    assert_response :success
    assert_select 'turbo-frame#search_section a.combobox--item[href=?][data-controller=?][data-action=?]',
                  bullet_path(bullet), 'recent-search', 'click->recent-search#record'
    selector = 'turbo-frame#search_section a.combobox--item[href=?]' \
               '[data-recent-search-searchable-type-value=?][data-recent-search-searchable-id-value=?]'
    assert_select selector, bullet_path(bullet), 'Bullet', bullet.id.to_s
  end
end
