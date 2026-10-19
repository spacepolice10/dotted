# frozen_string_literal: true

require 'application_system_test_case'

class BulletMenuMoreSystemTest < ApplicationSystemTestCase
  setup do
    page.current_window.resize_to(1400, 1400)
    @user = users(:one)
    sign_in_as(@user)
    @bullet = create_bullet!(@user, body: 'Additional actions')
  end

  test 'desktop shows publishing actions and hotkeys inline' do
    visit bullets_path
    assert_no_selector 'dialog#more_dialog[open]'
    assert_no_selector '#more_dialog turbo-frame', visible: :all
    select_bullet
    within '.bullet-menu' do
      assert_button 'Note', exact: true
      assert_button 'Done', exact: true
      assert_button 'Publish', exact: true
      assert_no_button 'More', exact: true
    end
    columns = page.evaluate_script("getComputedStyle(document.querySelector('.bullet-menu--actions')).gridTemplateColumns.split(' ').length")
    assert_equal 1, columns
    assert_equal true, page.evaluate_script(<<~JS)
      [...document.querySelectorAll('.bullet-menu--actions button')]
        .filter(button => button.getClientRects().length)
        .every(button => button.scrollWidth <= button.clientWidth)
    JS

    badges = page.evaluate_script(<<~JS)
      [...document.querySelectorAll('.bullet-menu .hotkey-hint[data-hotkey]')]
        .filter(button => button.getClientRects().length)
        .map(button => {
          const badge = getComputedStyle(button, '::after')
          return { content: badge.content, display: badge.display, opacity: badge.opacity }
        })
    JS
    assert_equal ['"C"', '"L"', '"S"'], badges.map { |badge| badge['content'] }
    assert badges.all? { |badge| %w[flex inline-flex].include?(badge['display']) && badge['opacity'] == '1' }, badges.inspect
    within '.bullet-menu' do
      assert_selector "input[name=bullet_ids][value='#{@bullet.id}']", visible: :all
      click_button 'Publish', exact: true
    end
    assert_no_selector 'dialog#more_dialog[open]'
    assert_no_selector '.bullet-menu'
    assert @bullet.reload.published?

    select_bullet
    within '.bullet-menu' do
      assert_button 'Unpublish', exact: true
      assert_button 'Copy publish link', exact: true
      assert_no_button 'Publish', exact: true
      click_button 'Unpublish', exact: true
    end
    assert_no_selector 'dialog#more_dialog[open]'
    assert_not @bullet.reload.published?
  end

  test 'closing more keeps the selection and opens options for a new selection' do
    page.current_window.resize_to(390, 844)
    other = create_bullet!(@user, body: 'Another bullet')
    visit bullets_path
    select_bullet
    assert_no_selector '.bullet-menu--desktop-actions'
    assert_equal 'none', page.evaluate_script("getComputedStyle(document.querySelector('.bullet-menu [data-hotkey=C]'), '::after').display")
    click_button 'More', exact: true
    assert_selector 'dialog#more_dialog[open] button', text: 'Publish', exact_text: true
    find('dialog#more_dialog').send_keys(:escape)
    assert_no_selector 'dialog#more_dialog[open]'
    assert_selector '.bullet-menu--count', text: '1 selected'

    page.execute_script("document.querySelector('#bullet_#{other.id} [data-bullet-menu-target=checkbox]').click()")
    click_button 'More', exact: true
    assert_selector "#more_dialog input[name=bullet_ids][value='#{@bullet.id},#{other.id}']", visible: :all
    within '#more_dialog' do
      click_button 'Publish', exact: true
    end
    assert_no_selector 'dialog#more_dialog[open]'
    assert @bullet.reload.published?
    assert other.reload.published?
  end

  test 'publishing actions stay synchronized when switching between mobile and desktop' do
    @bullet.publish!
    visit bullets_path
    select_bullet
    within '.bullet-menu' do
      assert_button 'Unpublish', exact: true
      assert_button 'Copy publish link', exact: true
      assert_no_button 'Publish', exact: true
    end

    page.current_window.resize_to(390, 844)
    click_button 'More', exact: true
    within '#more_dialog' do
      assert_button 'Unpublish', exact: true
      assert_button 'Copy publish link', exact: true
      assert_no_button 'Publish', exact: true
      click_button 'Unpublish', exact: true
    end

    assert_no_selector 'dialog#more_dialog[open]'
    assert_no_selector '.bullet-menu'
    select_bullet
    page.current_window.resize_to(1400, 1400)
    within '.bullet-menu' do
      assert_button 'Publish', exact: true
      assert_no_button 'Unpublish', exact: true
      assert_no_button 'Copy publish link', exact: true
      assert_no_button 'More', exact: true
    end
  end

  test 'mobile opens the note editor from more and hides note for multiple bullets' do
    page.current_window.resize_to(390, 844)
    other = create_bullet!(@user, body: 'Another bullet')
    visit bullets_path
    select_bullet
    assert_no_selector '.bullet-menu button[data-bullet-menu-target=note]'
    click_button 'More', exact: true
    within '#more_dialog' do
      assert_button 'Note', exact: true
      assert_selector '[data-bullet-menu-target=note] .icon-wrap[style*="--model-color-4"]'
      click_button 'Note', exact: true
    end
    assert_no_selector '#more_dialog[open]'
    assert_selector '#note_dialog[open] lexxy-editor'
    find('#note_dialog').send_keys(:escape)

    page.execute_script("document.querySelector('#bullet_#{other.id} [data-bullet-menu-target=checkbox]').click()")
    click_button 'More', exact: true
    within '#more_dialog' do
      assert_no_button 'Note', exact: true
    end
  end

  private

  def select_bullet
    page.execute_script("document.querySelector('#bullet_#{@bullet.id} [data-bullet-menu-target=checkbox]').click()")
    assert_selector '.bullet-menu'
    page.document.synchronize do
      running = page.evaluate_script("document.querySelector('.bullet-menu').getAnimations().some(animation => animation.playState == 'running')")
      raise Capybara::ExpectationNotMet if running
    end
  end
end
