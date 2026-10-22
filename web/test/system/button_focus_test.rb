# frozen_string_literal: true

require 'application_system_test_case'

class ButtonFocusSystemTest < ApplicationSystemTestCase
  setup do
    sign_in_as(users(:one))
  end

  test 'a keyboard-focused button shows the accent ring' do
    visit search_path
    find('#search button[aria-label=Search]').click

    # Real typing puts the page in keyboard modality, so a subsequent
    # programmatic focus matches :focus-visible the way Tab would.
    find('dialog#search_picker_dialog input[name=search_term]').set('m')

    assert_selector 'dialog#search_picker_dialog[aria-labelledby=search_picker_dialog_title]'
    assert_selector '#search_picker_dialog_title', text: 'Search'

    close = 'dialog#search_picker_dialog .dialog--hide'
    page.execute_script("document.querySelector('#{close}').focus()")

    assert page.evaluate_script("document.querySelector('#{close}').matches(':focus-visible')"),
      'expected the close button to match :focus-visible'
    assert_equal '2px', page.evaluate_script("getComputedStyle(document.querySelector('#{close}')).outlineWidth")
    assert_equal 'solid', page.evaluate_script("getComputedStyle(document.querySelector('#{close}')).outlineStyle")
  end

  test 'colour choices show keyboard focus independently of selection' do
    visit new_collection_path
    find('input[name="collection[name]"]').set('Ideas')

    radios = all('input[name="collection[colour]"]', visible: :all)
    assert_operator radios.size, :>, 1
    radios.first.send_keys(:space)
    radios.first.send_keys(:arrow_right)

    focused_label = page.evaluate_script(<<~JS)
      (() => {
        const input = document.activeElement;
        const label = input.closest('label');
        if (!input.matches('input[name="collection[colour]"]:focus-visible') || !label) return null;
        const style = getComputedStyle(label);
        return [style.outlineWidth, style.outlineStyle, style.outlineOffset];
      })()
    JS
    assert_equal ['2px', 'solid', '2px'], focused_label
  end
end
