# frozen_string_literal: true

require 'application_system_test_case'

class ThemesSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test 'account links to visuals and Turbo saves the selected theme without a reload' do
    visit user_path
    assert_no_selector '.appearance-settings'
    click_link 'Visuals'
    assert_current_path user_visuals_path
    assert_selector 'h1', text: 'Visuals'
    page.execute_script('window.visualsVisitToken = "same-document"')

    pick_theme 'Kazakstans Skyview', 'kazakstans_skyview'
    assert_equal 'same-document', page.evaluate_script('window.visualsVisitToken'), 'expected Turbo to handle the form submission'
    assert_equal 'kazakstans_skyview', @user.reload.settings.appearance
    assert_selector 'body[data-appearance=kazakstans_skyview]'
    assert_includes background_image, 'kazakstans-skyview'

    visit bullets_path
    assert_selector 'body[data-appearance=kazakstans_skyview]'
    page.refresh
    assert_selector 'body[data-appearance=kazakstans_skyview]'

    visit user_visuals_path
    pick_theme 'Dotted', 'default'
    assert_equal 'default', @user.reload.settings.appearance
    refute_includes background_image, 'kazakstans-skyview'
    assert_no_text 'Theme saved'
  end

  test 'swatches are keyboard accessible native submit buttons' do
    visit user_visuals_path
    find_button('Refurbished').send_keys(:tab)
    button = find_button('Refurbished')
    page.execute_script('arguments[0].focus()', button)
    assert_selector 'button[value=refurbished]:focus-visible'
    assert_equal 'solid', page.evaluate_script("getComputedStyle(document.querySelector('button[value=refurbished]')).outlineStyle")
    button.send_keys(:enter)
    assert_selector 'button[value=refurbished][aria-pressed=true]'
    assert_equal 'refurbished', @user.reload.settings.appearance
    assert_selector '.appearance-name', text: 'Refurbished'
  end

  test 'the same SVG adapts to day and night and fits narrow screens' do
    create_bullet!(@user, body: 'A little space to collect a thought.')

    %w[kazakstans_skyview refurbished].each do |theme|
      @user.settings!.update!(appearance: theme)
      images = []
      canvases = []
      %w[light dark].each do |mode|
        page.driver.browser.execute_cdp('Emulation.setEmulatedMedia', features: [
          { name: 'prefers-color-scheme', value: mode },
          { name: 'prefers-reduced-motion', value: 'reduce' }
        ])
        [1400, 320].each do |width|
          page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: width, height: 1000, deviceScaleFactor: 1, mobile: width == 320)
          visit bullets_path
          pattern = theme == 'kazakstans_skyview' ? 'kazakstans-skyview' : theme
          assert_includes background_image, pattern
          images << background_image
          canvases << page.evaluate_script('getComputedStyle(document.documentElement).backgroundColor')
          loaded = page.driver.browser.execute_async_script(<<~JS)
            const done = arguments[arguments.length - 1];
            const url = getComputedStyle(document.documentElement).backgroundImage.split('"')[1];
            const img = new Image();
            img.onload = () => done(img.naturalWidth === 1600 && img.naturalHeight === 1200);
            img.onerror = () => done(false);
            img.src = url;
          JS
          assert loaded, 'expected the background SVG to load at its intended size'
          assert_operator page.evaluate_script('document.documentElement.scrollWidth'), :<=,
                          page.evaluate_script('document.documentElement.clientWidth')
          if ENV['THEME_PREVIEW_DIR']
            page.save_screenshot(File.join(ENV['THEME_PREVIEW_DIR'], "#{theme}-#{mode}-#{width}.png"))
            visit user_visuals_path
            page.save_screenshot(File.join(ENV['THEME_PREVIEW_DIR'], "visuals-#{theme}-#{mode}-#{width}.png"))
          end
        end
      end
      assert_equal 1, images.uniq.size, 'expected one shared SVG URL for both light and dark mode'
      assert_equal 2, canvases.uniq.size, 'expected day and night canvas colours'
    end
  end

  test 'Tetradka saves silently through the visuals form' do
    visit user_visuals_path
    pick_theme 'Tetradka', 'tetradka'
    assert_equal 'tetradka', @user.reload.settings.appearance
    assert_no_text 'Theme saved'
    assert_includes background_image, 'linear-gradient'
    refute_includes background_image, 'radial-gradient'
  end

  private

  def pick_theme(name, value)
    click_button name
    assert_current_path user_visuals_path
    assert_selector "button[value='#{value}'][aria-pressed=true]"
    assert_selector "body[data-appearance='#{value}']"
  end

  def background_image
    page.evaluate_script('getComputedStyle(document.documentElement).backgroundImage')
  end
end
