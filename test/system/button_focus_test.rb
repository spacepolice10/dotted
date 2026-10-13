# frozen_string_literal: true

require 'application_system_test_case'

class ButtonFocusSystemTest < ApplicationSystemTestCase
  setup do
    sign_in_as(users(:one))
  end

  test 'a keyboard-focused button shows the accent ring' do
    visit search_path
    find('#search_dock button[aria-label=Search]').click

    # Real typing puts the page in keyboard modality, so a subsequent
    # programmatic focus matches :focus-visible the way Tab would.
    find('dialog#search_picker_dialog input[name=q]').set('m')

    close = 'dialog#search_picker_dialog .dialog--hide'
    page.execute_script("document.querySelector('#{close}').focus()")

    assert page.evaluate_script("document.querySelector('#{close}').matches(':focus-visible')"),
      'expected the close button to match :focus-visible'
    assert_equal '2px', page.evaluate_script("getComputedStyle(document.querySelector('#{close}')).outlineWidth")
    assert_equal '2px', page.evaluate_script("getComputedStyle(document.querySelector('#{close}')).outlineWidth")
    assert_equal 'solid', page.evaluate_script("getComputedStyle(document.querySelector('#{close}')).outlineStyle")
  end
end
