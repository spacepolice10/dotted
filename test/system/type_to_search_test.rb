# frozen_string_literal: true

require 'application_system_test_case'

class TypeToSearchSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test 'a letter opens search and subsequent typing continues the query' do
    bullet = create_bullet!(@user, body: 'Fly a kite')
    visit search_path

    find('body').send_keys('k')
    field = find('#search_picker_dialog[open] input[name=q]:focus')
    assert_equal 'k', field.value
    field.send_keys('ite')

    assert_equal 'kite', field.value
    assert_selector "#search_picker_dialog a[href='#{bullet_path(bullet)}'] mark.search--term", text: 'kite'
    assert_current_path search_path
  end

  test 'hidden bullet shortcuts do not swallow letters and a new search replaces the old query' do
    visit bullets_path

    %w[c l s K].each do |letter|
      find('body').send_keys(letter)
      assert_equal letter, find('#search_picker_dialog[open] input[name=q]:focus').value
      page.execute_script("document.querySelector('#search_picker_dialog').close()")
    end

    # ChromeDriver sends an empty key for accented text through send_keys.
    page.execute_script("document.body.dispatchEvent(new KeyboardEvent('keydown', { key: 'é', bubbles: true, cancelable: true }))")
    assert_equal 'é', find('#search_picker_dialog[open] input[name=q]:focus').value
  end

  test 'digits punctuation modifiers and composition do not open search' do
    visit search_path
    find('body').send_keys('4', '.', '/', :space, :arrow_down)
    assert_no_selector '#search_picker_dialog[open]'

    page.execute_script(<<~JS)
      for (const options of [{ctrlKey: true}, {metaKey: true}, {altKey: true}, {isComposing: true}, {keyCode: 229}, {repeat: true}]) {
        document.body.dispatchEvent(new KeyboardEvent('keydown', { key: 'a', bubbles: true, cancelable: true, ...options }))
      }
    JS
    assert_no_selector '#search_picker_dialog[open]'
  end

  test 'typing in the composer stays in the editor' do
    visit bullets_path
    editor = find('#bullet_composer .lexxy-editor__content')
    editor.send_keys('Keep writing here')

    assert_equal 'Keep writing here', editor.text
    assert_no_selector '#search_picker_dialog[open]'
  end

  test 'typing in a regular input stays in the input' do
    visit search_results_path
    field = find('#search_dock input[name=q]')
    field.send_keys('keep')

    assert_equal 'keep', field.value
    assert_no_selector '#search_picker_dialog[open]'
  end

  test 'selection mode keeps bullet shortcuts and other dialogs keep their own keyboard handling' do
    bullet = create_bullet!(@user, body: 'Select me')
    visit bullets_path
    page.execute_script("document.querySelector('#bullet_#{bullet.id} input').click()")
    assert_selector '.bullet-menu'

    find('.bullet-menu').send_keys('l')
    assert_selector '#postpone_dialog[open]'
    assert_no_selector '#search_picker_dialog[open]'

    find('#postpone_dialog').send_keys('k')
    assert_no_selector '#search_picker_dialog[open]'
    assert_selector '#postpone_dialog[open]'
  end

  test 'the existing control k shortcut still opens search' do
    visit search_path
    find('body').send_keys([:control, 'k'])

    assert_selector '#search_picker_dialog[open] input[name=q]'
    assert_equal '', find('#search_picker_dialog input[name=q]').value
  end
end
