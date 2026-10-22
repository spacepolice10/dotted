# frozen_string_literal: true

require 'application_system_test_case'

class BulletMenuMoreSystemTest < ApplicationSystemTestCase
  setup do
    page.current_window.resize_to(1400, 1400)
    @user = users(:one)
    sign_in_as(@user)
    @bullet = create_bullet!(@user, body: 'Additional actions')
  end

  test 'desktop publishes inline and keeps the link available until unpublishing' do
    visit bullets_path
    select_bullet
    within '.bullet-menu' do
      assert_button 'Note', exact: true
      assert_button 'Done', exact: true
      assert_link 'Publishing…'
      assert_no_button 'Publish', exact: true
      assert_no_button 'More', exact: true
      click_link 'Publishing…'
      assert_text 'anyone with its public link'
      click_button 'Publish', exact: true
      assert_button 'Unpublish', exact: true
      assert_button 'Copy', exact: true
      assert_no_button 'Publish', exact: true
      assert_selector "input[aria-label='Public link'][readonly]"
    end
    assert @bullet.reload.published?
    assert_selector '.bullet-menu--count', text: '1 selected'
    assert_equal published_url(@bullet.public_code), find('.bullet-menu input[aria-label="Public link"]').value

    page.execute_script(<<~JS)
      window.copiedPublishingLink = null;
      Object.defineProperty(navigator, 'clipboard', {
        configurable: true,
        value: { writeText: async (text) => { window.copiedPublishingLink = text } }
      });
    JS
    within '.bullet-menu' do
      click_button 'Copy', exact: true
    end
    assert_text 'Publish link copied'
    assert_equal published_url(@bullet.public_code), page.evaluate_script('window.copiedPublishingLink')

    within '.bullet-menu' do
      click_button 'Unpublish', exact: true
      assert_button 'Publish', exact: true
      assert_no_button 'Copy', exact: true
      assert_no_selector "input[aria-label='Public link']"
    end
    assert_not @bullet.reload.published?
    assert_selector '.bullet-menu--count', text: '1 selected'
  end

  test 'changing selection resets publishing and supports multiple bullets on mobile' do
    page.current_window.resize_to(390, 844)
    other = create_bullet!(@user, body: 'Another bullet')
    visit bullets_path
    select_bullet
    click_button 'More', exact: true
    within '#more_dialog' do
      click_link 'Publishing…'
      assert_button 'Publish', exact: true
    end
    find('dialog#more_dialog').send_keys(:escape)
    assert_selector '.bullet-menu--count', text: '1 selected'

    page.execute_script("document.querySelector('#bullet_#{other.id} [data-bullet-menu-target=checkbox]').click()")
    click_button 'More', exact: true
    within '#more_dialog' do
      assert_link 'Publishing…'
      assert_no_button 'Publish', exact: true
      click_link 'Publishing…'
      click_button 'Publish', exact: true
      assert_selector "input[aria-label='Public link']", count: 2
      assert_button 'Unpublish', exact: true
    end
    assert_selector 'dialog#more_dialog[open]'
    assert @bullet.reload.published?
    assert other.reload.published?
  end

  test 'existing publishing state stays synchronized between mobile and desktop' do
    @bullet.publish!
    visit bullets_path
    select_bullet
    within '.bullet-menu' do
      click_link 'Publishing…'
      assert_button 'Unpublish', exact: true
      assert_button 'Copy', exact: true
      assert_no_button 'Publish', exact: true
    end

    page.current_window.resize_to(390, 844)
    click_button 'More', exact: true
    within '#more_dialog' do
      assert_button 'Copy', exact: true
      click_button 'Unpublish', exact: true
      assert_button 'Publish', exact: true
    end
    find('dialog#more_dialog').send_keys(:escape)
    page.current_window.resize_to(1400, 1400)
    within '.bullet-menu' do
      assert_button 'Publish', exact: true
      assert_no_button 'Unpublish', exact: true
      assert_no_button 'Copy', exact: true
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
