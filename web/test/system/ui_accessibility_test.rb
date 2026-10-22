# frozen_string_literal: true

require 'application_system_test_case'

class UiAccessibilitySystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test 'reduced motion preserves dialog opening closing and focus return' do
    emulate(reduced: true)
    visit search_path
    trigger = find('#search button[aria-label=Search]')
    trigger.send_keys(:enter)
    assert_selector '#search_picker_dialog[open]'
    assert_equal '0s', computed('#search_picker_dialog', 'transitionDuration')
    assert_equal '0s', computed('#search_picker_dialog', 'transitionDuration', '::backdrop')
    find('#search_picker_dialog').send_keys(:escape)
    assert_no_selector '#search_picker_dialog[open]'
    assert_selector '#search button[aria-label=Search]:focus'
  end

  test 'reduced motion keeps radio selection immediate and visible' do
    emulate(reduced: true)
    visit new_collection_path
    input = all('input[name="collection[colour]"]', visible: :all).first
    input.send_keys(:space)
    assert_selector 'label:has(input[name="collection[colour]"]:checked)'
    selector = 'label:has(input[name="collection[colour]"]:checked)'
    assert_equal 'none', computed(selector, 'animationName', '::after')
    assert_equal 'solid', computed(selector, 'outlineStyle')
  end

  test 'reduced motion removes toast shaking while retaining automatic dismissal' do
    emulate(reduced: true)
    visit search_path
    # Exercise the real toast host and target-connected lifecycle.
    page.execute_script(<<~JS)
      document.querySelector('#toasts').insertAdjacentHTML('beforeend',
        '<div class="toasts--message toasts--notify" data-toasts-target="notify" role="status">Saved</div>');
    JS
    assert_selector '.toasts--message', text: 'Saved'
    assert_equal 'toasts--fade-away', computed('.toasts--message', 'animationName')
    assert_equal '0.001s', computed('.toasts--message', 'animationDuration')
    assert_no_selector '.toasts--message', wait: 5
  end

  test 'keyboard focus stays visible on schedule options and selected search results' do
    bullet = create_bullet!(@user, body: 'Readable result')
    visit bullets_path
    find('body').send_keys(:tab)
    page.execute_script("document.querySelector('#bullet_#{bullet.id} input').focus()")
    page.execute_script("document.querySelector('#bullet_#{bullet.id} input').click()")
    assert_selector '.bullet-menu:focus-visible'
    assert_equal 'solid', computed('.bullet-menu', 'outlineStyle')
    find_button('Later').send_keys(:enter)
    option = find('#postpone_dialog .picker--item:focus')
    option.send_keys(:arrow_down)
    assert_selector '#postpone_dialog .picker--item:focus-visible'
    assert_equal 'solid', computed('#postpone_dialog .picker--item:focus-visible', 'outlineStyle')
    assert_equal '2px', computed('#postpone_dialog .picker--item:focus-visible', 'outlineWidth')

    visit search_path
    find('#search button[aria-label=Search]').click
    find('#search_picker_dialog input[name=search_term]').set('Readable')
    assert_selector '#search_picker_dialog .combobox--item[aria-selected=true]'
    page.execute_script("document.querySelector('#search_picker_dialog .combobox--item').focus()")
    assert_equal 'solid', computed('#search_picker_dialog .combobox--item', 'outlineStyle')
  end

  test 'form placeholders and muted result text remain readable in both themes at narrow widths' do
    create_bullet!(@user, body: 'Readable result')
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: 390, height: 844, deviceScaleFactor: 1, mobile: false)
    %w[light dark].each do |theme|
      emulate(theme: theme)
      visit bullets_path
      assert_text_contrast('.composer .lexxy-editor__content', pseudo: '::before')
      find('.composer .lexxy-editor__content').send_keys('Legible text')
      assert_text_contrast('.composer .lexxy-editor__content')

      visit new_collection_path
      assert_text_contrast('input[name="collection[name]"]', pseudo: '::placeholder')
      assert_operator computed('body', 'fontSize').to_f, :>=, 15
      assert_text_contrast('input[name="collection[name]"]', property: 'outlineColor', minimum: 3)

      visit search_results_path(search_term: 'Readable')
      assert_selector '.search--result-type'
      assert_text_contrast('.search--result-type')
      assert_operator computed('.search--result-type', 'fontSize').to_f, :>=, 13

      # Doubling the user's default font size exercises text scaling without
      # merely zooming a screenshot; the viewport stays narrow.
      page.execute_script("document.documentElement.style.fontSize = '200%'")
      assert_operator computed('body', 'fontSize').to_f, :>=, 30
      assert_operator page.evaluate_script('document.documentElement.scrollWidth'), :<=,
                      page.evaluate_script('document.documentElement.clientWidth')
    end
  end

  test 'published and postponed badge labels stay readable in both themes' do
    published = create_bullet!(@user, body: 'Published')
    published.publish!
    postponed = create_bullet!(@user, body: 'Postponed', last_postponed_at: Time.current)
    %w[light dark].each do |theme|
      emulate(theme: theme)
      [published, postponed].each do |bullet|
        visit bullet_path(bullet)
        assert_text_contrast('.bullet--status > span:not(.icon-wrap)')
      end
    end
  end

  private

  def emulate(theme: 'light', reduced: false)
    page.driver.browser.execute_cdp('Emulation.setEmulatedMedia', features: [
      { name: 'prefers-color-scheme', value: theme },
      { name: 'prefers-reduced-motion', value: reduced ? 'reduce' : 'no-preference' }
    ])
  end

  def computed(selector, property, pseudo = nil)
    page.evaluate_script('getComputedStyle(document.querySelector(arguments[0]), arguments[2])[arguments[1]]', selector, property, pseudo)
  end

  def assert_text_contrast(selector, pseudo: nil, property: 'color', minimum: 4.5)
    ratio = page.evaluate_script(<<~JS, selector, pseudo, property)
      (() => {
        const element = document.querySelector(arguments[0]);
        const style = getComputedStyle(element, arguments[1]);
        const ctx = document.createElement('canvas').getContext('2d');
        const rgba = color => {
          ctx.clearRect(0, 0, 1, 1); ctx.fillStyle = color; ctx.fillRect(0, 0, 1, 1);
          return [...ctx.getImageData(0, 0, 1, 1).data].map((v, i) => i === 3 ? v / 255 : v);
        };
        const over = (fg, bg) => fg.slice(0, 3).map((v, i) => v * fg[3] + bg[i] * (1 - fg[3])).concat(1);
        const ancestors = [];
        for (let node = element; node; node = node.parentElement) ancestors.unshift(node);
        let background = [255, 255, 255, 1];
        for (const node of ancestors) background = over(rgba(getComputedStyle(node).backgroundColor), background);
        const foreground = rgba(style[arguments[2]]);
        foreground[3] *= Number(style.opacity);
        const luminance = rgb => rgb.slice(0, 3).map(v => {
          v /= 255; return v <= .04045 ? v / 12.92 : ((v + .055) / 1.055) ** 2.4;
        }).reduce((sum, v, i) => sum + v * [.2126, .7152, .0722][i], 0);
        const a = luminance(over(foreground, background)), b = luminance(background);
        return (Math.max(a, b) + .05) / (Math.min(a, b) + .05);
      })()
    JS
    assert_operator ratio, :>=, minimum, "#{selector} #{pseudo}: contrast #{ratio.round(2)}:1"
  end
end
