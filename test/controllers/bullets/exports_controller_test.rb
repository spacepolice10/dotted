# frozen_string_literal: true

require 'test_helper'

module Bullets
  class ExportsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @collection = create_collection!(@user, name: 'Reading List')
      @first = create_bullet!(@user,
        body: 'First bullet',
        collection: @collection,
        pops_on: Date.current - 2
      )
      @second = create_bullet!(@user,
        body: 'Second bullet',
        collection: @collection,
        pops_on: Date.current - 1
      )
    end

    test 'show downloads html for filtered active bullets' do
      get export_bullets_path(collection: @collection.name)

      assert_response :success
      assert_includes response.media_type, 'text/html'
      assert_match(/attachment; filename="dotted-reading-list-export-\d{4}-\d{2}-\d{2}\.html"/,
                   response.headers['Content-Disposition'])
      assert_match '<!DOCTYPE html>', response.body
      assert_match 'First bullet', response.body
      assert_match 'Second bullet', response.body
      assert_match 'reading list export', response.body
    end

    test 'show orders bullets by day' do
      get export_bullets_path(collection: @collection.name)

      assert_response :success
      assert_operator response.body.index('First bullet'), :<, response.body.index('Second bullet')
    end

    test 'show excludes completed bullets' do
      @first.complete!

      get export_bullets_path(collection: @collection.name)

      assert_response :success
      assert_no_match 'First bullet', response.body
      assert_match 'Second bullet', response.body
    end

    test 'show excludes upcoming bullets from default due export' do
      create_bullet!(@user, body: 'Future bullet', collection: @collection, pops_on: Date.current + 3)

      get export_bullets_path(collection: @collection.name)

      assert_response :success
      assert_no_match 'Future bullet', response.body
    end

    test 'show returns not found for unknown collection' do
      get export_bullets_path(collection: 'missing')

      assert_response :not_found
    end

    test 'show returns not found for deleted collection' do
      name = @collection.name
      @collection.destroy!

      get export_bullets_path(collection: name)

      assert_response :not_found
    end
  end
end
