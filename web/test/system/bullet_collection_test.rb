# frozen_string_literal: true

require 'application_system_test_case'

class BulletCollectionSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test 'collection shows incomplete bullets across dates and removes one when completed' do
    collection = create_collection!(@user, name: 'Reading')
    past = create_bullet!(@user, body: 'Read yesterday', collection: collection, pops_on: Date.current - 3)
    future = create_bullet!(@user, body: 'Read later', collection: collection, pops_on: Date.current + 3)
    completed = create_bullet!(@user, body: 'Already read', collection: collection)
    completed.complete!

    visit collection_path(collection)

    assert_selector ".collection--bullets #bullet_#{past.id}"
    assert_selector ".collection--bullets #bullet_#{future.id}"
    assert_no_selector ".collection--bullets #bullet_#{completed.id}"
    assert_no_selector '.timeline--section'
    assert page.evaluate_script(<<~JS)
      (() => {
        const page = document.querySelector('.collection-page')
        const header = page.querySelector('.collection-header')
        const lane = page.querySelector('.collection--lane')
        const title = lane.querySelector('h2')
        return getComputedStyle(page).paddingBlockStart === '0px' &&
          getComputedStyle(header).position === 'absolute' &&
          lane.getBoundingClientRect().top >= header.getBoundingClientRect().bottom &&
          parseFloat(getComputedStyle(title).borderBottomWidth) > 0 &&
          getComputedStyle(title).backgroundColor !== getComputedStyle(lane).backgroundColor
      })()
    JS

    find("#bullet_#{past.id} .bullet--select-square").click
    within '.bullet-menu' do
      click_button 'Done'
    end

    assert_no_selector ".collection--bullets #bullet_#{past.id}"
    assert_selector ".collection--bullets #bullet_#{future.id}"
  end

  test 'collection picker moves bullets between lanes without changing their dates' do
    collection = create_collection!(@user, name: 'Reading')
    bullet = create_bullet!(@user, body: 'Keep its date', collection: collection, pops_on: Date.current - 4)

    visit collection_path(collection)
    assert_selector ".collection--lane[data-lane=unsorted] #bullet_#{bullet.id}"

    find("#bullet_#{bullet.id} .bullet--select-square").click
    click_button 'Tag'
    within '#collects_dialog .collect-picker--collection' do
      click_button 'Parked'
    end
    assert_selector ".collection--lane[data-lane=parked] #bullet_#{bullet.id}"
    assert_equal Date.current - 4, bullet.reload.pops_on

    find("#bullet_#{bullet.id} .bullet--select-square").click
    click_button 'Tag'
    within '#collects_dialog .collect-picker--collection' do
      click_button collection.name
    end
    assert_selector ".collection--lane[data-lane=unsorted] #bullet_#{bullet.id}"
  end

  test 'bullet menu moves selected collection bullets to the next and previous lane' do
    collection = create_collection!(@user, name: 'Reading')
    first = create_bullet!(@user, body: 'First', collection: collection)
    second = create_bullet!(@user, body: 'Second', collection: collection)

    visit collection_path(collection)
    [first, second].each { |bullet| find("#bullet_#{bullet.id} .bullet--select-square").click }
    assert page.evaluate_script(<<~JS)
      (() => {
        const actions = document.querySelector('.collection-item-menu-actions')
        const menu = document.querySelector('.collection-item-menu-wrapper > .bullet-menu')
        return actions.getBoundingClientRect().bottom <= menu.getBoundingClientRect().top &&
          !menu.contains(actions)
      })()
    JS
    within '.collection-item-menu-actions' do
      assert_button 'Next'
      assert_no_button 'Prev'
      click_button 'Next'
    end
    assert_selector '.collection--lane[data-lane=parked] .collection--item', count: 2
    assert_equal [second.id, first.id], collection.parked_items.map(&:bullet_id)

    find("#bullet_#{first.id} .bullet--select-square").click
    within '.collection-item-menu-actions' do
      assert_button 'Prev'
      assert_no_button 'Next'
      click_button 'Prev'
    end
    assert_selector ".collection--lane[data-lane=unsorted] #bullet_#{first.id}"
    assert_selector ".collection--lane[data-lane=parked] #bullet_#{second.id}"
  end

  test 'long collection name stays inside the header on mobile' do
    page.current_window.resize_to(390, 844)
    collection = create_collection!(@user, name: 'A' * 120)

    visit collection_path(collection)

    assert page.evaluate_script(<<~JS)
      (() => {
        const header = document.querySelector('.collection-header')
        const title = header.querySelector('h1')
        const headerRect = header.getBoundingClientRect()
        const titleRect = title.getBoundingClientRect()
        return headerRect.left >= 0 && headerRect.right <= innerWidth &&
          titleRect.right <= headerRect.right && title.scrollWidth > title.clientWidth &&
          getComputedStyle(title).textOverflow === 'ellipsis'
      })()
    JS
  end

  test 'dragging a whole bullet into empty Parked lane moves it there' do
    collection = create_collection!(@user, name: 'Reading')
    bullet = create_bullet!(@user, body: 'Drag me', collection: collection)

    visit collection_path(collection)
    assert_no_selector '.collection--drag-handle'
    find("#collection_item_bullet_#{bullet.id}").drag_to(find('.collection--lane[data-lane=parked]'))

    assert_selector ".collection--lane[data-lane=parked] #bullet_#{bullet.id}"
    assert_equal [bullet.id], collection.collection_items.pluck(:bullet_id)
  end

  test 'collection board drag reorders parked bullets' do
    collection = create_collection!(@user, name: 'Reading')
    first = create_bullet!(@user, body: 'First', collection: collection)
    second = create_bullet!(@user, body: 'Second', collection: collection)
    collection.move_bullet!(bullet_id: first.id, lane: 'parked')
    collection.move_bullet!(bullet_id: second.id, lane: 'parked')

    visit collection_path(collection)
    page.execute_script(<<~JS)
      const item = document.querySelector('#collection_item_bullet_#{first.id}')
      const parked = document.querySelector('.collection--lane[data-lane=parked]')
      const second = document.querySelector('#collection_item_bullet_#{second.id}')
      const dataTransfer = new DataTransfer()
      const clientY = second.getBoundingClientRect().top + 1
      item.dispatchEvent(new DragEvent('dragstart', { bubbles: true, dataTransfer }))
      parked.dispatchEvent(new DragEvent('dragover', { bubbles: true, cancelable: true, dataTransfer, clientY }))
      parked.dispatchEvent(new DragEvent('drop', { bubbles: true, cancelable: true, dataTransfer, clientY }))
      item.dispatchEvent(new DragEvent('dragend', { bubbles: true, dataTransfer }))
    JS

    assert_selector ".collection--lane[data-lane=parked] #collection_item_bullet_#{first.id}:first-child"
    assert_equal [first.id, second.id], collection.parked_items.map(&:bullet_id)
  end

  test 'mobile collection lanes snap horizontally while each list scrolls vertically' do
    page.current_window.resize_to(390, 844)
    collection = create_collection!(@user, name: 'Reading')
    bullets = 24.times.map { |index| create_bullet!(@user, body: "Bullet #{index}", collection: collection) }
    collection.move_bullets!(bullet_ids: bullets.first(12).map(&:id), lane: 'parked')

    visit collection_path(collection)
    assert_includes page.evaluate_script("getComputedStyle(document.querySelector('.collection-board')).scrollSnapType"), 'x'
    assert page.evaluate_script(<<~JS)
      (() => {
        const board = document.querySelector('.collection-board')
        const unsorted = board.querySelector('.collection--lane[data-lane=unsorted] .collection--bullets')
        const parked = board.querySelector('.collection--lane[data-lane=parked]')
        const parkedList = parked.querySelector('.collection--bullets')
        return board.scrollWidth > board.clientWidth &&
          unsorted.scrollHeight > unsorted.clientHeight &&
          parkedList.scrollHeight > parkedList.clientHeight &&
          getComputedStyle(unsorted).overflowY === 'auto' &&
          getComputedStyle(parkedList).overflowY === 'auto' &&
          board.scrollHeight <= board.clientHeight + 1 &&
          parked.getBoundingClientRect().width <= board.clientWidth
      })()
    JS
    assert page.evaluate_script(<<~JS)
      (() => {
        const board = document.querySelector('.collection-board')
        const unsorted = board.querySelector('.collection--lane[data-lane=unsorted] .collection--bullets')
        const parked = board.querySelector('.collection--lane[data-lane=parked] .collection--bullets')
        unsorted.scrollTop = 100
        const parkedBefore = parked.scrollTop
        parked.scrollTop = 100
        return unsorted.scrollTop > 0 && parkedBefore === 0 && parked.scrollTop > 0 && board.scrollLeft === 0
      })()
    JS

    page.execute_script(<<~JS)
      const item = document.querySelector('#collection_item_bullet_#{bullets[1].id}')
      const parked = document.querySelector('.collection--lane[data-lane=parked]')
      const first = document.querySelector('#collection_item_bullet_#{bullets[0].id}')
      const dataTransfer = new DataTransfer()
      const clientY = first.getBoundingClientRect().top + 1
      item.dispatchEvent(new DragEvent('dragstart', { bubbles: true, dataTransfer }))
      parked.dispatchEvent(new DragEvent('dragover', { bubbles: true, cancelable: true, dataTransfer, clientY }))
      parked.dispatchEvent(new DragEvent('drop', { bubbles: true, cancelable: true, dataTransfer, clientY }))
      item.dispatchEvent(new DragEvent('dragend', { bubbles: true, dataTransfer }))
    JS
    assert_selector ".collection--lane[data-lane=parked] #collection_item_bullet_#{bullets[1].id}:first-child"
    assert page.evaluate_script(<<~JS)
      (() => {
        const board = document.querySelector('.collection-board')
        const unsorted = board.querySelector('.collection--lane[data-lane=unsorted] .collection--bullets')
        const parked = board.querySelector('.collection--lane[data-lane=parked] .collection--bullets')
        return unsorted.scrollTop >= 99 && parked.scrollTop >= 99
      })()
    JS
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
