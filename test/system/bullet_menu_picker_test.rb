# frozen_string_literal: true

require 'application_system_test_case'

class BulletMenuPickerSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @bullet = create_bullet!(@user, body: 'Selectable line', created_at: Time.current)
    create_collection!(@user, name: 'Reading')
  end

  test 'later opens the schedule dialog and focuses its first option' do
    visit bullets_path
    select_bullet

    find_button('Later').click

    assert_selector 'dialog#postpone_dialog[open]'
    assert_selector 'dialog#postpone_dialog h2', text: 'Schedule'
    assert_selector 'dialog#postpone_dialog button[data-grid-navigation-target="item"]', minimum: 1
    assert_selector 'dialog#postpone_dialog button[data-grid-navigation-target="item"]:focus'
    assert_equal 'Today', focused_option_label
  end

  test 'escape closes the schedule dialog but keeps the selection' do
    visit bullets_path
    select_bullet
    find_button('Later').click
    assert_selector 'dialog#postpone_dialog[open]'

    find('dialog#postpone_dialog').send_keys(:escape)

    assert_no_selector 'dialog#postpone_dialog[open]'
    assert_text '1 selected'
    assert_selector '.bullet-menu', visible: true
  end

  test 'escape with no dialog open clears the selection' do
    visit bullets_path
    select_bullet
    assert_text '1 selected'

    find('.bullet-menu').send_keys(:escape)

    assert_no_selector '.bullet-menu', visible: true
  end

  test 'scheduling a bullet closes the dialog and clears the selection' do
    visit bullets_path
    select_bullet
    find_button('Later').click
    assert_selector 'dialog#postpone_dialog[open]'

    find('dialog#postpone_dialog button[data-grid-navigation-target="item"]', match: :first).click

    assert_no_selector 'dialog#postpone_dialog[open]'
    assert_no_selector '.bullet-menu', visible: true
  end

  test 'confirm schedules the manually selected date' do
    target = Date.current + 3.days

    visit bullets_path
    select_bullet
    find_button('Later').click
    assert_selector 'dialog#postpone_dialog[open] input[type=date]'

    page.execute_script(
      "document.querySelector('dialog#postpone_dialog input[type=date]').value = arguments[0]",
      target.iso8601
    )
    find_button('Confirm').click

    assert_no_selector 'dialog#postpone_dialog[open]'
    assert_no_selector '.bullet-menu', visible: true
    assert_equal target, @bullet.reload.pops_on
  end

  test 'save opens the collections dialog and closes it on the chrome button' do
    visit bullets_path
    select_bullet

    find_button('Tag').click

    wait_for_dialog 'dialog#collects_dialog[open]'
    assert_selector 'dialog#collects_dialog h2', text: 'To collection'
    assert_selector 'dialog#collects_dialog #collects-collections-list', text: 'reading'

    find('dialog#collects_dialog button[command="close"]').click

    assert_no_selector 'dialog#collects_dialog[open]'
    assert_text '1 selected'
  end

  test 'collecting a bullet closes the dialog and clears the selection' do
    visit bullets_path
    select_bullet
    find_button('Tag').click
    wait_for_dialog 'dialog#collects_dialog[open]'

    find('dialog#collects_dialog #collects-collections-list form button',
         match: :first).click

    assert_no_selector 'dialog#collects_dialog[open]'
    assert_no_selector '.bullet-menu', visible: true
  end

  test 'enter collects into the selected collection' do
    create_collection!(@user, name: 'Ideas')
    visit bullets_path
    select_bullet
    find_button('Tag').click
    field = find('dialog#collects_dialog input[name=search_term]')
    field.set('read')
    assert_selector 'dialog#collects_dialog #collects-collections-list button.combobox--item', text: 'reading'
    assert_no_selector 'dialog#collects_dialog #collects-collections-list button.combobox--item', text: 'ideas'

    field.send_keys(:arrow_down)
    assert_selector 'dialog#collects_dialog button.combobox--item[aria-selected=true]', text: 'reading'
    field.send_keys(:enter)

    assert_no_selector 'dialog#collects_dialog[open]'
    assert_equal 'reading', @bullet.reload.collection.name
  end

  test 'submitting a bullet menu action clears the selection' do
    visit bullets_path
    select_bullet

    find_button('Done', exact: true).click

    assert_no_selector '.bullet-menu', visible: true
    assert_selector "#bullet_#{@bullet.id}[data-bullet-done=true]"

    select_bullet
    find_button('Undo', exact: true).click

    assert_selector "#bullet_#{@bullet.id}[data-bullet-done=false]"
  end

  private

  def select_bullet
    page.execute_script("document.querySelector('[data-bullet-menu-target=checkbox]').click()")
    assert_selector '.bullet-menu', visible: true
    page.document.synchronize do
      running = page.evaluate_script("document.querySelector('.bullet-menu').getAnimations().some(animation => animation.playState == 'running')")
      raise Capybara::ExpectationNotMet if running
    end
  end

  def wait_for_dialog(selector)
    assert_selector selector
    page.document.synchronize do
      running = page.evaluate_script("document.querySelector(arguments[0]).getAnimations().some(animation => animation.playState == 'running')", selector)
      raise Capybara::ExpectationNotMet if running
    end
  end

  def focused_option_label
    page.evaluate_script('document.activeElement?.textContent?.trim().split("\\n")[0]')
  end
end
