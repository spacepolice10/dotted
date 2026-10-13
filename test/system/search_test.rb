# frozen_string_literal: true

require 'application_system_test_case'

class SearchSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @field = 'input.search--textform[name=q]'
  end

  # --- the navigation page opens the search dialog ---

  test 'the navigation page preloads the dialog with no visible field' do
    visit search_path

    assert_selector '#search_navigation'
    assert_selector 'dialog#search_picker_dialog', visible: false
    assert_no_selector 'dialog#search_picker_dialog[open]'
    assert_no_selector 'a.combobox--item'
  end

  test 'activating the field stand-in opens the search dialog' do
    visit search_path

    find('#search_dock button[aria-label=Search]').click

    assert_current_path search_path
    assert_selector 'dialog#search_picker_dialog[open]'
    assert_selector 'dialog#search_picker_dialog input[name=q]'
  end

  test 'typing in the dialog filters results without leaving the page' do
    recent = create_bullet!(@user, body: 'Call the plumber')
    match = create_bullet!(@user, body: 'Buy milk today')

    visit search_path
    find('#search_dock button[aria-label=Search]').click
    find('dialog#search_picker_dialog input[name=q]').set('milk')

    assert_selector "dialog#search_picker_dialog a.combobox--item[href='#{bullet_path(match)}'] mark.search--term",
                    text: 'milk'
    assert_no_selector "dialog#search_picker_dialog a.combobox--item[href='#{bullet_path(recent)}']"
    assert_current_path search_path
  end

  test 'the palette trigger is preloaded on other pages' do
    match = create_bullet!(@user, body: 'Buy milk today')

    visit bullets_path

    assert_selector 'button[commandfor=search_picker_dialog]', visible: false
    assert_selector 'dialog#search_picker_dialog', visible: false

    page.execute_script("document.querySelector('button[commandfor=search_picker_dialog]').click()")

    assert_selector 'dialog#search_picker_dialog[open]'
    find('dialog#search_picker_dialog input[name=q]').set('milk')

    assert_selector "dialog#search_picker_dialog a.combobox--item[href='#{bullet_path(match)}'] mark.search--term",
                    text: 'milk'
    assert_current_path bullets_path
  end

  test 'escape with an empty field closes the dialog' do
    visit search_path
    find('#search_dock button[aria-label=Search]').click
    assert_selector 'dialog#search_picker_dialog[open]'

    find('dialog#search_picker_dialog input[name=q]').send_keys(:escape)

    assert_no_selector 'dialog#search_picker_dialog[open]'
  end

  test 'escape with text clears the field first, then closes' do
    match = create_bullet!(@user, body: 'Buy milk today')

    visit search_path
    find('#search_dock button[aria-label=Search]').click
    field = find('dialog#search_picker_dialog input[name=q]')
    field.set('milk')
    assert_selector "dialog#search_picker_dialog a.combobox--item[href='#{bullet_path(match)}']"

    field.send_keys(:escape)

    assert_equal '', field.value
    assert_selector 'dialog#search_picker_dialog[open]'
    assert_no_selector 'dialog#search_picker_dialog a.combobox--item'

    field.send_keys(:escape)

    assert_no_selector 'dialog#search_picker_dialog[open]'
  end

  test 'the results route is visitable on its own' do
    matching = create_bullet!(@user, body: 'Buy milk today')

    visit search_results_path(q: 'milk')

    assert_selector "#search_section a.combobox--item[href='#{bullet_path(matching)}'] mark.search--term", text: 'milk'
    assert_equal 'milk', find(@field).value
  end

  test 'the results route ignores navigation params and lands on the empty state' do
    create_bullet!(@user, body: 'Buy milk today')

    visit search_path(q: 'milk')

    assert_selector '#search_navigation'
    assert_no_selector 'a.combobox--item'
  end

  test 'clicking a result records a recent search' do
    bullet = create_bullet!(@user, body: 'Buy milk today')

    visit bullets_path
    page.execute_script("document.querySelector('button[commandfor=search_picker_dialog]').click()")
    assert_selector 'dialog#search_picker_dialog[open]'

    find('dialog#search_picker_dialog input[name=q]').set('milk')
    find("dialog#search_picker_dialog a.combobox--item[href='#{bullet_path(bullet)}']").click

    assert_selector 'main.timeline--window--focus'

    selection = nil
    10.times do
      selection = Search::Selection.find_by(user: @user, searchable_type: 'Bullet', searchable_id: bullet.id)
      break if selection

      sleep 0.5
    end

    assert_equal bullet.id, selection&.searchable_id
  end

  test 'tab skips result links while arrows still navigate the list' do
    create_bullet!(@user, body: 'Buy milk today')
    create_bullet!(@user, body: 'Buy milk tomorrow')

    visit bullets_path
    page.execute_script("document.querySelector('button[commandfor=search_picker_dialog]').click()")
    assert_selector 'dialog#search_picker_dialog[open]'

    field = find('dialog#search_picker_dialog input[name=q]')
    field.set('milk')
    assert_selector 'dialog#search_picker_dialog a.combobox--item', count: 2

    field.send_keys(:tab)

    assert page.evaluate_script("!document.activeElement.closest('a.combobox--item')"),
           'expected tab to skip result links to the element after the list'
  end

  # --- typing updates the frame ---

  test 'typing updates the results inside the section frame' do
    recent = create_bullet!(@user, body: 'Call the plumber')
    match = create_bullet!(@user, body: 'Buy milk today')

    visit search_results_path
    find(@field).set('milk')

    assert_selector "#search_section a.combobox--item[href='#{bullet_path(match)}'] mark.search--term", text: 'milk'
    assert_no_selector "#search_section a.combobox--item[href='#{bullet_path(recent)}']"
  end

  test 'the input keeps focus and caret across a frame update' do
    create_bullet!(@user, body: 'Buy milk today')

    visit search_results_path
    find(@field).send_keys('milk')
    assert_selector '#search_section mark.search--term', text: 'milk'

    # The frame wraps only the list, so re-rendering must not steal focus or
    # reset the value out from under the caret.
    assert_equal 'milk', find(@field).value
    assert page.evaluate_script("document.activeElement === document.querySelector('input.search--textform[name=q]')"),
           'expected the input to still hold focus after the frame updated'
  end

  test 'clearing the query returns to the empty state' do
    create_bullet!(@user, body: 'Buy milk today')

    visit search_results_path(q: 'milk')
    assert_selector '#search_section a.combobox--item'

    find('.search--cleanup').click

    assert_selector '#search_section .empty-state h2', text: 'No results'
    assert_no_selector '#search_section a.combobox--item'
  end

  test 'the first result is visible above the field without any scrolling' do
    shrink_viewport
    10.times { |i| create_bullet!(@user, body: "Buy milk #{i} #{'pad ' * 40}") }

    visit search_results_path
    find(@field).set('milk')
    assert_selector '#search_section mark.search--term'

    assert_operator first_result_top, :>=, 0, 'expected the first result inside the viewport'
    assert_operator first_result_top, :<, dock_top, 'expected the first result above the search field'
  end

  test 'arrow keys move the current-item highlight across results' do
    create_bullet!(@user, body: 'Buy milk today')
    create_bullet!(@user, body: 'Buy milk tomorrow')

    visit search_path
    find('#search_dock button[commandfor="search_picker_dialog"]').click
    field = find('dialog#search_picker_dialog input[name=q]')
    field.set('milk')

    first = 'dialog#search_picker_dialog ul[role=listbox] a.combobox--item:nth-of-type(1)'
    second = 'dialog#search_picker_dialog ul[role=listbox] a.combobox--item:nth-of-type(2)'
    assert_selector 'dialog#search_picker_dialog a.combobox--item', count: 2
    assert_equal 'true', find(first)['aria-selected']
    assert_equal 'false', find(second)['aria-selected']

    field.send_keys(:arrow_down)

    assert_equal 'false', find(first)['aria-selected']
    assert_equal 'true', find(second)['aria-selected']
  end

  private

  # Ten unclamped rows only overflow on a short viewport.
  def shrink_viewport
    page.current_window.resize_to(500, 700)
  end

  def dock_top
    page.evaluate_script("document.querySelector('#search_dock').getBoundingClientRect().top")
  end

  def first_result_top
    page.evaluate_script("Math.round(document.querySelector('a.combobox--item').getBoundingClientRect().top)")
  end
end
