# frozen_string_literal: true

require 'application_system_test_case'

class BulletCollectionSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test 'a collection pill sits below bullet text as non-interactive information' do
    collection = create_collection!(@user, name: 'Reading', colour: 'cobalt', icon: 'books')
    bullet = create_bullet!(@user, body: '<p>Read a book</p>', collection: collection)
    visit bullets_path

    within "#bullet_#{bullet.id} .bullet--body" do
      pill = find('span.bullet--collection', text: collection.name)
      assert_no_selector 'a.bullet--collection'
      assert_nil pill[:tabindex]
      assert_selector '.bullet--collection .icon[style*="--icon-hash"]'
      assert_includes pill[:style], '--model-color-2'
    end
    below_text = page.evaluate_script(<<~JS)
      (() => {
        const body = document.querySelector('#bullet_#{bullet.id} .bullet--body');
        const text = body.querySelector('.lexxy-content').getBoundingClientRect();
        const pill = body.querySelector('.bullet--collection').getBoundingClientRect();
        return pill.top >= text.bottom && pill.bottom <= body.getBoundingClientRect().bottom;
      })()
    JS
    assert below_text, 'expected the collection pill below the text and inside the bullet body'
    body = "#bullet_#{bullet.id} .bullet--body"
    appearance = -> { page.evaluate_script("(() => { const s = getComputedStyle(document.querySelector(arguments[0])); return [s.backgroundColor, s.borderColor, s.boxShadow]; })()", body) }
    before_hover = appearance.call
    find(body).hover
    assert_equal before_hover, appearance.call
    find("#bullet_#{bullet.id} .bullet--collection").click
    assert_current_path bullets_path
  end

  test 'long collection names wrap within a narrow bullet in both themes' do
    collection = create_collection!(@user, name: 'Long collection ' * 8, colour: 'emerald')
    bullet = create_bullet!(@user, body: 'A thought', collection: collection)
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: 320, height: 844, deviceScaleFactor: 1, mobile: true)
    %w[light dark].each do |theme|
      page.driver.browser.execute_cdp('Emulation.setEmulatedMedia', features: [{ name: 'prefers-color-scheme', value: theme }])
      visit bullet_path(bullet)
      assert_selector '.bullet--collection', text: collection.name
      assert_operator page.evaluate_script('document.documentElement.scrollWidth'), :<=,
                      page.evaluate_script('document.documentElement.clientWidth')
    end
  end

  test 'collection and status chips share one wrapping row inside the bullet body' do
    collection = create_collection!(@user, name: 'Plans', colour: 'mint')
    postponed = create_bullet!(@user, body: 'Later', collection: collection, last_postponed_at: Time.current)
    published = create_bullet!(@user, body: 'Shared', collection: collection)
    published.publish!
    [postponed, published].each do |bullet|
      visit bullet_path(bullet)
      assert_selector '.bullet--body > .bullet--metadata .bullet--collection'
      assert_selector ".bullet--body > .bullet--metadata .bullet--status--#{bullet.status}"
      rows = page.evaluate_script(<<~JS)
        [...document.querySelector('.bullet--metadata').children].map(el => el.getBoundingClientRect().top)
      JS
      assert_in_delta rows.first, rows.last, 1
    end
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width: 320, height: 844, deviceScaleFactor: 1, mobile: true)
    assert_operator page.evaluate_script('document.documentElement.scrollWidth'), :<=,
                    page.evaluate_script('document.documentElement.clientWidth')
  end

  test 'attachment bullets retain their preview or download alongside the collection' do
    collection = create_collection!(@user, name: 'Reference', colour: 'mint', icon: 'folder')
    image = create_file_bullet!(@user, filename: 'pixel.png', content_type: 'image/png',
                               io: StringIO.new(Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a7L8AAAAASUVORK5CYII=')),
                               collection: collection)
    file = create_file_bullet!(@user, filename: 'reference.txt', content_type: 'text/plain', collection: collection)
    visit bullets_path
    assert_selector "#bullet_#{image.id} .attachment--preview-picture img"
    assert_selector "#bullet_#{image.id} .bullet--collection", text: collection.name
    assert_selector "#bullet_#{file.id} .attachment--preview-icon"
    assert_selector "#bullet_#{file.id} .attachment--preview-name", text: 'reference.txt'
    assert_selector "#bullet_#{file.id} .bullet--collection", text: collection.name
  end

  test 'uncollected bullets have no pill and public bullets omit collection names' do
    plain = create_bullet!(@user, body: 'Uncollected')
    collection = create_collection!(@user, name: 'Private collection')
    shared = create_bullet!(@user, body: 'Shared thought', collection: collection)
    shared.publish!
    visit bullet_path(plain)
    assert_no_selector '.bullet--collection'
    visit published_path(shared.public_code)
    assert_text 'Shared thought'
    assert_no_selector '.bullet--collection'
    assert_no_text collection.name
  end
end
