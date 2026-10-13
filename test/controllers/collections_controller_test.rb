# frozen_string_literal: true

require 'test_helper'

class CollectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'create saves the collection and redirects to the index' do
    assert_difference -> { Collection.count }, 1 do
      post collections_path, params: {
        collection: { name: 'Inbox', colour: 'teal', icon: 'folder', description: 'Things to sort' }
      }
    end

    assert_equal 'Things to sort', Collection.last.description
    assert_redirected_to collections_path
  end

  test 'new with bullet_ids renders full page form and preview' do
    card = create_bullet!(@user, body: 'Preview me')

    get new_collection_path, params: { bullet_ids: card.id.to_s, return_to: search_path }

    assert_response :success
    assert_select 'main[data-size="sm"]'
    assert_select 'main a[aria-label="Back to Search"]', count: 0
    assert_select 'nav.tabbar--back a.tabbar--back-link[href=?][aria-label=?]', search_path, 'Back to Search', text: 'Back'
    assert_select 'form.form button[type="submit"][data-intent="primary"]', text: 'Create and collect'
    assert_select 'input[name="bullet_ids"][value=?]', card.id.to_s
    assert_match 'Preview me', response.body
    assert_match '1 bullet will be added', response.body
  end

  test 'create with bullet_ids collects bullets and redirects' do
    first = create_bullet!(@user, body: 'One')
    second = create_bullet!(@user, body: 'Two')

    assert_difference -> { Collection.count }, 1 do
      post collections_path,
           params: {
             collection: { name: 'Fresh inbox', colour: 'teal', icon: 'folder' },
             bullet_ids: "#{first.id},#{second.id}"
           }
    end

    collection = Collection.last
    assert_redirected_to collection_path(collection)
    assert_equal collection, first.reload.collection
    assert_equal collection, second.reload.collection
  end

  test 'create with bullet_ids redirects back to return_to' do
    card = create_bullet!(@user, body: 'Move me')

    post collections_path,
         params: {
           collection: { name: 'Return path', colour: 'teal', icon: 'folder' },
           bullet_ids: card.id.to_s,
           return_to: search_path
         }

    assert_redirected_to search_path
    assert_equal Collection.last, card.reload.collection
  end

  test 'create with invalid collection and bullet_ids re-renders full page form' do
    card = create_bullet!(@user, body: 'Hold')

    assert_no_difference -> { Collection.count } do
      post collections_path,
           params: {
             collection: { name: '', colour: 'teal', icon: 'folder' },
             bullet_ids: card.id.to_s,
             return_to: search_path
           }
    end

    assert_response :unprocessable_entity
    assert_nil card.reload.collection
    assert_select 'main[data-size="sm"]'
    assert_match 'Create and collect', response.body
    assert_match 'Hold', response.body
  end

  test 'filtered feed lists a bullet collected into the collection' do
    collection = create_collection!(@user, name: 'Inbox', colour: 'teal')
    bullet = create_bullet!(@user, body: 'Collected in', pops_on: Date.current)
    bullet.collect!(collection_id: collection.id)

    get bullets_path(collection: collection.name)

    assert_response :success
    assert_select "turbo-frame##{dom_id(collection, :timeline)}"
    assert_select "turbo-frame##{dom_id(bullet)}" do
      assert_select '.bullet--marker', count: 1
      assert_select 'label.bullet--select-checkbox[aria-label=?]', 'Select bullet', count: 1
      assert_select '[popover]', count: 0
    end
    assert_no_match 'Moved into inbox.', response.body
  end

  test 'filtered feed does not mount a composer' do
    collection = create_collection!(@user, name: 'Inbox')

    get bullets_path(collection: collection.name)

    assert_response :success
    assert_select "##{ActionView::RecordIdentifier.dom_id(collection, :bullets_composer)}", count: 0
    assert_select '#timeline_composer_dock', count: 0
    assert_select '.composer--dock', count: 0
  end

  test 'filtered feed still mounts the today section' do
    collection = create_collection!(@user, name: 'Inbox')
    create_bullet!(@user, collection: collection, body: 'Tagged row', pops_on: Date.current - 3)

    get bullets_path(collection: collection.name)

    assert_response :success
    assert_select 'div#timeline_section_current_date'
    assert_select 'div#timeline_section_current_date .bullet', count: 0
  end

  test 'filtered feed has no collection management header' do
    collection = create_collection!(@user, name: 'Inbox', colour: 'teal', icon: 'folder')

    get bullets_path(collection: collection.name)

    assert_response :success
    assert_select '.timeline--window'
    assert_select "turbo-frame##{dom_id(collection, :timeline)}.utilities--contents .timeline--scroller"
    assert_select 'button[popovertarget="collection_actions"]', count: 0
    assert_select 'h1', count: 0
  end

  test 'show renders the management panel and lazy timeline frame' do
    collection = create_collection!(@user, name: 'Inbox', colour: 'teal', icon: 'folder')

    get collection_path(collection)

    assert_response :success
    assert_select 'main > header nav h1', text: 'inbox'
    assert_select 'button[popovertarget="collection_actions"]'
    assert_select 'div#collection_actions[role=menu][data-controller=grid-navigation]'
    assert_select 'a.dropdown-item[href=?]', edit_collection_path(collection)
    assert_select 'a.dropdown-item[href=?]', export_bullets_path(collection: collection.name)
    assert_select "turbo-frame##{dom_id(collection, :timeline)}.utilities--contents[src=?]",
                  bullets_path(collection: collection.name)
  end

  test 'filtered feed groups tagged bullets into timeline sections' do
    collection = create_collection!(@user, name: 'Inbox')

    create_bullet!(@user, collection: collection, body: 'Older day', pops_on: Date.current - 2)
    create_bullet!(@user, collection: collection, body: 'Yesterday', pops_on: Date.current - 1)
    create_bullet!(@user, body: 'Untagged', pops_on: Date.current - 1)
    create_bullet!(@user, collection: collection, body: 'Today', pops_on: Date.current)

    get bullets_path(collection: collection.name)

    assert_response :success
    assert_match 'Older day', response.body
    assert_match 'Yesterday', response.body
    assert_match 'Today', response.body
    assert_no_match 'Untagged', response.body
  end

  test 'update changes collection attributes and description' do
    collection = create_collection!(@user, name: 'Old name', colour: 'teal', icon: 'folder')
    collection.update!(description: 'Original')

    patch collection_path(collection), params: {
      collection: { name: 'New name', colour: 'gold', icon: 'heart', description: 'Updated' }
    }

    assert_redirected_to collection_path(collection)
    collection.reload
    assert_equal 'new name', collection.name
    assert_equal 'Updated', collection.description
    assert_equal 'gold', collection.colour
    assert_equal 'heart', collection.icon
  end

  test 'destroy hard-deletes collection and keeps bullets untagged' do
    collection = create_collection!(@user, name: 'Gone')
    card = create_bullet!(@user, body: 'Stays', collection: collection)

    assert_difference -> { Collection.count }, -1 do
      delete collection_path(collection)
    end

    assert_redirected_to search_path
    assert_not Collection.exists?(collection.id)
    assert Bullet.exists?(card.id)
    assert_nil card.reload.collection
  end
end
