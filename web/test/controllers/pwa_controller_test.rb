# frozen_string_literal: true

require 'test_helper'

class PwaControllerTest < ActionDispatch::IntegrationTest
  test 'manifest is public and installable' do
    get pwa_manifest_path(format: :json)

    assert_response :success
    manifest = response.parsed_body
    assert_equal 'Dotted', manifest['short_name']
    assert_equal 'standalone', manifest['display']
    assert_includes manifest['icons'].pluck('sizes'), '192x192'
    assert_includes manifest['icons'].pluck('purpose'), 'maskable'
  end

  test 'service worker is public and only caches fingerprinted assets' do
    get '/service-worker.js'

    assert_response :success
    assert_includes response.body, 'startsWith("/assets/")'
  end

  test 'every manifest icon exists in public' do
    get pwa_manifest_path(format: :json)

    response.parsed_body['icons'].pluck('src').uniq.each do |src|
      assert Rails.public_path.join(src.delete_prefix('/')).file?, "missing #{src}"
    end
  end
end
