# frozen_string_literal: true

require 'test_helper'

class Bookmark::UnfurlerTest < ActiveSupport::TestCase
  FakeHTTP = Struct.new(:responses) do
    def request_get(_path, _headers)
      responses.shift.tap { |response| yield response }
    end
  end

  test 'extracts Open Graph metadata and resolves relative images' do
    html = <<~HTML
      <html><head>
        <title>Fallback title</title>
        <meta property="og:title" content="  Article title  ">
        <link rel="shortcut icon" href="../favicon.png">
      </head></html>
    HTML

    metadata = metadata_for(html, url: 'https://example.com/news/article')

    assert_equal 'Article title', metadata[:title]
    assert_equal 'https://example.com/favicon.png', metadata[:icon_link]
  end

  test 'falls back to the HTML title and conventional favicon' do
    metadata = metadata_for('<meta property="og:title" content="  "><title>  A page  </title>')

    assert_equal 'A page', metadata[:title]
    assert_nil metadata[:icon_link]
  end

  test 'resolves HTTP icons for the guarded server-side fetch' do
    html = '<link rel="icon" href="http://example.com/icon.png">'
    metadata = metadata_for(html)

    assert_equal 'http://example.com/icon.png', metadata[:icon_link]
  end

  test 'rejects icon URLs with credentials or alternate ports' do
    %w[https://user:pass@example.com/icon.png https://example.com:8443/icon.png].each do |url|
      metadata = metadata_for(%(<link rel="icon" href="#{url}">))

      assert_nil metadata[:icon_link], url
    end
  end

  test 'fetches an icon from a pinned public address' do
    with_http_responses(icon_response) do |connections|
      unfurler = Bookmark::Unfurler.new('https://8.8.8.8/article')
      unfurler.instance_variable_set(:@final_link, 'https://8.8.8.8/article')

      icon = unfurler.download_icon('https://8.8.8.8/favicon.png')

      assert_equal 'image/png', icon[:content_type]
      assert_equal png_icon, icon[:io].read
      assert_equal '8.8.8.8', connections.first[:ipaddr]
    end
  end

  test 'returns the title and downloaded favicon together' do
    html = '<title>Example</title><link rel="icon" href="/icon.png">'
    with_http_responses(html_response(chunks: [html]), icon_response) do |connections|
      attributes = Bookmark::Unfurler.new('https://8.8.8.8/article').call

      assert_equal 'Example', attributes[:title]
      assert_equal 'https://8.8.8.8/icon.png', attributes[:icon_link]
      assert_equal png_icon, attributes[:favicon][:io].read
      assert_equal 2, connections.size
    end
  end

  test 'falls back when a declared icon points to a private address' do
    with_http_responses(icon_response) do |connections|
      unfurler = Bookmark::Unfurler.new('https://8.8.8.8/article')
      unfurler.instance_variable_set(:@final_link, 'https://8.8.8.8/article')

      icon = unfurler.download_icon('http://127.0.0.1/private')

      assert_equal 'https://8.8.8.8/favicon.ico', icon[:link]
      assert_equal 1, connections.size
    end
  end

  test 'does not follow an icon redirect into a private address' do
    with_http_responses(redirect_response('http://127.0.0.1/private'), icon_response) do |connections|
      unfurler = Bookmark::Unfurler.new('https://8.8.8.8/article')
      unfurler.instance_variable_set(:@final_link, 'https://8.8.8.8/article')

      icon = unfurler.download_icon('https://8.8.8.8/other-icon.png')

      assert_equal 'https://8.8.8.8/favicon.ico', icon[:link]
      assert_equal 2, connections.size
    end
  end

  test 'rejects a fake image response' do
    with_http_responses(html_response(chunks: ['<script>'], content_type: 'image/png'),
                        html_response(chunks: ['<script>'], content_type: 'image/png')) do
      unfurler = Bookmark::Unfurler.new('https://8.8.8.8/article')
      unfurler.instance_variable_set(:@final_link, 'https://8.8.8.8/article')

      assert_nil unfurler.download_icon('https://8.8.8.8/other-icon.png')
    end
  end

  test 'rejects local addresses before making a request' do
    %w[http://127.0.0.1/ http://[::1]/ http://localhost:3000/].each do |url|
      assert_raises(Bookmark::Unfurler::FetchError) { Bookmark::Unfurler.new(url).call }
    end
  end

  test 'rejects alternate ports and credentials' do
    %w[https://example.com:8443/ https://user:pass@example.com/].each do |url|
      assert_raises(Bookmark::Unfurler::FetchError) { Bookmark::Unfurler.new(url).call }
    end
  end

  test 'pins the public destination and blocks a redirect into the private network' do
    with_http_responses(redirect_response('http://127.0.0.1/')) do |connections|
      assert_raises(Bookmark::Unfurler::FetchError) { Bookmark::Unfurler.new('https://8.8.8.8/').call }

      assert_equal 1, connections.size
      assert_equal '8.8.8.8', connections.first[:ipaddr]
      assert_nil connections.first[:proxy]
      assert connections.first[:use_ssl]
    end
  end

  test 'stops reading when the streamed response exceeds the size limit' do
    chunks = ['x' * Bookmark::Unfurler::SIZE, 'x']
    with_http_responses(html_response(chunks: chunks)) do
      error = assert_raises(Bookmark::Unfurler::FetchError) { Bookmark::Unfurler.new('https://8.8.8.8/').call }
      assert_equal 'response is too large', error.message
    end
  end

  test 'rejects non-HTML responses' do
    with_http_responses(html_response(content_type: 'application/json')) do
      assert_raises(Bookmark::Unfurler::FetchError) { Bookmark::Unfurler.new('https://8.8.8.8/').call }
    end
  end

  test 'bounds the redirect chain' do
    responses = Array.new(Bookmark::Unfurler::REDIRECTS + 1) { redirect_response('/again') }
    with_http_responses(*responses) do |connections|
      error = assert_raises(Bookmark::Unfurler::FetchError) { Bookmark::Unfurler.new('https://8.8.8.8/').call }
      assert_equal 'too many redirects', error.message
      assert_equal Bookmark::Unfurler::REDIRECTS + 1, connections.size
    end
  end

  test 'follows a relative redirect and extracts metadata from the response' do
    with_http_responses(redirect_response('/article'), html_response) do |connections|
      unfurler = Bookmark::Unfurler.new('https://8.8.8.8/')
      unfurler.define_singleton_method(:download_icon) { |_url| nil }
      metadata = unfurler.call

      assert_equal 'Example', metadata[:title]
      assert_equal 2, connections.size
      assert connections.all? { |connection| connection[:ipaddr] == '8.8.8.8' }
    end
  end

  private

  def metadata_for(html, url: 'https://example.com/')
    unfurler = Bookmark::Unfurler.new(url)
    unfurler.define_singleton_method(:download) { [url, html] }
    unfurler.define_singleton_method(:download_icon) do |preferred|
      if preferred
        { link: preferred.to_s, io: StringIO.new('icon'), filename: 'favicon.ico', content_type: 'image/x-icon' }
      end
    end
    unfurler.call
  end

  def html_response(chunks: ['<title>Example</title>'], content_type: 'text/html')
    Net::HTTPOK.new('1.1', '200', 'OK').tap do |response|
      response['content-type'] = content_type
      response.define_singleton_method(:read_body) { |&block| chunks.each(&block) }
    end
  end

  def icon_response
    html_response(chunks: [png_icon], content_type: 'image/png')
  end

  def png_icon
    "\x89PNG\r\n\x1a\nicon".b
  end

  def redirect_response(location)
    Net::HTTPFound.new('1.1', '302', 'Found').tap { |response| response['location'] = location }
  end

  def with_http_responses(*responses)
    original_start = Net::HTTP.method(:start)
    connections = []
    http = FakeHTTP.new(responses)
    Net::HTTP.define_singleton_method(:start) do |host, port, proxy, **options, &block|
      connections << { host: host, port: port, proxy: proxy, **options }
      block.call(http)
    end
    yield connections
  ensure
    Net::HTTP.define_singleton_method(:start, original_start)
  end
end
