# frozen_string_literal: true

require 'test_helper'

module Bullets
  class CollectsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
    end

    test 'create redirects to timeline and collects into collection' do
      collection = create_collection!(@user, name: 'Ideas')
      card = create_bullet!(@user, body: 'Move me')

      post collect_path, params: { bullet_ids: card.id.to_s, collection_id: collection.id }

      assert_redirected_to bullets_path
      assert_equal collection, card.reload.collection
    end

    test 'collecting keeps selected bullets on their original dates' do
      collection = create_collection!(@user, name: 'Ideas')
      bullets = [Date.current - 5, Date.current, Date.current + 5].map do |date|
        create_bullet!(@user, body: 'Revisited', pops_on: date)
      end

      post collect_path, params: { bullet_ids: bullets.map(&:id).join(','), collection_id: collection.id },
                         as: :turbo_stream

      assert_response :success
      assert_select 'turbo-stream[action=refresh]', count: 0
      assert_select 'turbo-stream[action=append][target=timeline_section_current_date]', count: 0
      bullets.zip([Date.current - 5, Date.current, Date.current + 5]).each do |bullet, date|
        assert_equal date, bullet.reload.pops_on
        assert_equal collection, bullet.collection
      end
    end

    test 'new renders collection picker for selected bullets' do
      collection = create_collection!(@user, name: 'Ideas')
      card = create_bullet!(@user, body: 'Move me')

      get new_collect_path, params: { bullet_ids: card.id.to_s }

      assert_response :success
      assert_select 'turbo-frame#collects_picker'
      assert_select '[popover]', count: 0
      assert_select 'form[action=?]', new_collect_path
      assert_select 'input[name="bullet_ids"][data-bullet-menu-target="idList"]'
      assert_match collection.name, response.body
    end

    test 'picker autofocuses on desktop but not on mobile' do
      card = create_bullet!(@user, body: 'Move me')

      get new_collect_path, params: { bullet_ids: card.id.to_s }

      assert_response :success
      assert_select 'turbo-frame#collects_picker input[name=search_term][autofocus]', count: 1

      get new_collect_path,
          params: { bullet_ids: card.id.to_s },
          headers: { 'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)' }

      assert_response :success
      assert_select 'turbo-frame#collects_picker input[name=search_term]', count: 1
      assert_select 'turbo-frame#collects_picker input[name=search_term][autofocus]', count: 0
    end

    test 'new renders picker content inside turbo frame request' do
      collection = create_collection!(@user, name: 'Ideas')
      card = create_bullet!(@user, body: 'Move me')

      get new_collect_path,
          params: { bullet_ids: card.id.to_s },
          headers: { 'Turbo-Frame' => 'collects_picker' }

      assert_response :success
      assert_select 'turbo-frame#collects_picker h2', text: 'To collection'
      assert_select 'input[name="bullet_ids"][data-bullet-menu-target="idList"]'
      assert_match collection.name, response.body
    end

    test 'new filters collections by search search term' do
      create_collection!(@user, name: 'alpha')
      create_collection!(@user, name: 'beta')
      card = create_bullet!(@user, body: 'Move me')

      get new_collect_path, params: { bullet_ids: card.id.to_s, search_term: 'alp' }

      assert_response :success
      assert_match 'alpha', response.body
      assert_no_match 'beta', response.body
    end

    test 'new renders collections list without pagination' do
      create_collection!(@user, name: 'Ideas')
      card = create_bullet!(@user, body: 'Move me')

      get new_collect_path, params: { bullet_ids: card.id.to_s }

      assert_select '#collects-collections-list'
      assert_select '#paginated-collects-collections', count: 0
      assert_select '[data-controller="pagination"]', count: 0
    end

    test 'new turbo stream replaces list container for live search' do
      create_collection!(@user, name: 'alpha')
      create_collection!(@user, name: 'beta')
      card = create_bullet!(@user, body: 'Move me')

      get new_collect_path,
          params: { bullet_ids: card.id.to_s, search_term: 'alp' },
          headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert_match %(turbo-stream action="replace" target="collects-collections-list"), response.body
      assert_match 'alpha', response.body
      assert_no_match 'beta', response.body
    end

    test 'new returns at most 10 collections' do
      11.times { |i| create_collection!(@user, name: format('Collection %02d', i)) }
      card = create_bullet!(@user, body: 'Move me')

      get new_collect_path, params: { bullet_ids: card.id.to_s }

      assert_response :success
      assert_select '#collects-collections-list .collect-picker--collection', count: 10
      assert_select '#collects-collections-list button.collect-picker--parked', count: 10
    end

    test 'new collection rows omit bullet count and date' do
      collection = create_collection!(@user, name: 'Ideas')
      card = create_bullet!(@user, body: 'Counted')
      card.collect!(collection_id: collection.id)

      get new_collect_path, params: { bullet_ids: card.id.to_s }

      assert_response :success
      assert_match collection.name, response.body
      assert_no_match(/\d+\s+bullets?/, response.body)
      assert_no_match collection.created_at.strftime('%b %d'), response.body
    end

    test 'picker heading links to full page create collection with bullet context' do
      card = create_bullet!(@user, body: 'Move me')

      get new_collect_path, params: { bullet_ids: card.id.to_s, return_to: bullets_path }

      assert_select 'a[href=?][data-turbo-frame=?]',
                    new_collection_path(bullet_ids: card.id.to_s, return_to: bullets_path),
                    '_top',
                    text: 'New collection'
    end

    test 'new ignores external return_to and falls back to referer' do
      card = create_bullet!(@user, body: 'Move me')

      get new_collect_path,
          params: { bullet_ids: card.id.to_s, return_to: 'https://evil.example/phish' },
          headers: { 'HTTP_REFERER' => search_path }

      assert_response :success
      assert_no_match 'evil.example', response.body
      assert_select 'a[href=?]',
                    new_collection_path(bullet_ids: card.id.to_s, return_to: search_path),
                    text: 'New collection'
    end

    test 'create collects bullet into selected collection' do
      card = create_bullet!(@user, body: 'Solo')
      collection = create_collection!(@user, name: 'scratchpad')

      post collect_path, params: { bullet_ids: card.id.to_s, collection_id: collection.id }

      assert_redirected_to bullets_path
      assert_equal collection, card.reload.collection
    end

    test 'create can place a bullet directly in Parked' do
      card = create_bullet!(@user, body: 'Solo', pops_on: Date.current + 4)
      collection = create_collection!(@user, name: 'scratchpad')

      post collect_path, params: { bullet_ids: card.id.to_s, collection_id: collection.id, lane: 'parked' }

      assert_redirected_to bullets_path
      assert_equal collection, card.reload.collection
      assert_equal Date.current + 4, card.pops_on
      assert_equal [card.id], collection.parked_items.map(&:bullet_id)
      assert_not_includes collection.unsorted_bullets, card
    end

    test 'create can move a parked bullet back to Unsorted in the same collection' do
      collection = create_collection!(@user, name: 'scratchpad')
      card = create_bullet!(@user, body: 'Solo', collection: collection)
      collection.move_bullet!(bullet_id: card.id, lane: 'parked')

      post collect_path, params: { bullet_ids: card.id.to_s, collection_id: collection.id, lane: 'unsorted' }, as: :turbo_stream

      assert_response :success
      assert_empty collection.collection_items.reload
      assert_includes collection.unsorted_bullets, card
      assert_select "turbo-stream[action=replace][target=#{dom_id(collection, :board)}]"
    end

    test 'create moves bullet out of its previous collection' do
      previous = create_collection!(@user, name: 'Previous')
      destination = create_collection!(@user, name: 'Destination')
      card = create_bullet!(@user, body: 'Move me', collection: previous)
      previous.move_bullet!(bullet_id: card.id, lane: 'parked')

      post collect_path, params: { bullet_ids: card.id.to_s, collection_id: destination.id }

      assert_redirected_to bullets_path
      assert_equal destination, card.reload.collection
      assert_empty previous.bullets
      assert_empty previous.collection_items.reload
    end

    test 'moving a bullet removes it from the previous collection page' do
      previous = create_collection!(@user, name: 'Previous')
      destination = create_collection!(@user, name: 'Destination')
      card = create_bullet!(@user, body: 'Move me', collection: previous)

      post collect_path,
           params: { bullet_ids: card.id.to_s, collection_id: destination.id },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert_match %(turbo-stream action="remove" targets=".collection-board[data-collection-id=#{previous.id}] #collection_item_bullet_#{card.id}"), response.body
      get collection_path(previous)
      assert_select ".collection--bullets ##{dom_id(card)}", count: 0
      get collection_path(destination)
      assert_select ".collection--bullets ##{dom_id(card)}", count: 1
    end

    test 'create collects multiple bullets into one collection' do
      collection = create_collection!(@user, name: 'Batch')
      first = create_bullet!(@user, body: 'One')
      second = create_bullet!(@user, body: 'Two')

      post collect_path,
           params: { bullet_ids: "#{first.id},#{second.id}", collection_id: collection.id }

      assert_redirected_to bullets_path
      assert_equal collection, first.reload.collection
      assert_equal collection, second.reload.collection
    end

    test 'create turbo stream keeps tagged bullets on the page' do
      collection = create_collection!(@user, name: 'Ideas')
      card = create_bullet!(@user, body: 'Collect me')

      post collect_path,
           params: { bullet_ids: card.id.to_s, collection_id: collection.id },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      card.reload
      assert_equal collection, card.collection
      assert_no_match %(turbo-stream action="remove"), response.body
      assert_match %(turbo-stream action="update" target="toasts"), response.body
      assert_match "Bullet collected into #{collection.name}", response.body
    end

    test 'create rejects collect into deleted collection' do
      collection = create_collection!(@user, name: 'Closed')
      collection.destroy!
      card = create_bullet!(@user, body: 'Move me')

      post collect_path, params: { bullet_ids: card.id.to_s, collection_id: collection.id }

      assert_response :not_found
      assert_nil card.reload.collection
    end
  end
end
