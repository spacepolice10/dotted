# frozen_string_literal: true

require 'net/http'
require 'stringio'
require 'surfguard'

class Bookmark::Unfurler
  class FetchError < StandardError; end

  SIZE = 256.kilobytes
  ICON_SIZE = 64.kilobytes
  REDIRECTS = 3
  ICON_TYPE = {
    'image/png' => 'png', 'image/jpeg' => 'jpg',
    'image/webp' => 'webp', 'image/x-icon' => 'ico', 'image/vnd.microsoft.icon' => 'ico'
  }.freeze

  def initialize(link)
    @link = link
  end

  def call
    final_link, html = download
    @final_link = final_link
    document = Nokogiri::HTML(html)
    title = document.at_css('meta[property="og:title"][content]')&.[]('content').presence || document.at_css('title')&.text
    icon = document.at_css('link[rel~="icon"][href]')

    attributes = { title: title&.squish&.truncate(255).presence }
    if (downloaded_icon = download_icon(resolve_icon_link(icon&.[]('href'), final_link)))
      attributes[:icon_link] = downloaded_icon[:link]
      attributes[:favicon] = downloaded_icon.slice(:io, :filename, :content_type)
    end
    attributes
  end

  def download_icon(preferred_link)
    [preferred_link, resolve_icon_link('/favicon.ico', @final_link)].compact.uniq.each do |icon_link|
      actual_link, body, content_type = download_resource(icon_link, size: ICON_SIZE, icon: true)
      extension = ICON_TYPE[content_type]
      next unless extension && icon_signature_valid?(body, content_type)

      return { link: actual_link, io: StringIO.new(body), filename: "favicon.#{extension}", content_type: content_type }
    rescue FetchError
      next
    end

    nil
  end

  private

  def icon_signature_valid?(body, content_type)
    case content_type
    when 'image/png' then body.start_with?("\x89PNG\r\n\x1a\n".b)
    when 'image/jpeg' then body.start_with?("\xff\xd8\xff".b)
    when 'image/webp' then body.start_with?('RIFF') && body.byteslice(8, 4) == 'WEBP'
    else body.start_with?("\x00\x00\x01\x00".b)
    end
  end

  def resolve_icon_link(value, base)
    return if value.blank?

    link = URI.join(base, value.strip)
    return unless link.is_a?(URI::HTTP) && link.host.present? && link.userinfo.nil? && link.port == link.default_port

    link
  end

  def download
    download_resource(@link, size: SIZE)
  end

  def download_resource(link, size:, icon: false)
    uri = URI.parse(link.to_s)

    (REDIRECTS + 1).times do
      unless uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil? && uri.port == uri.default_port
        raise FetchError, 'unsupported URL'
      end

      ip = Surfguard.resolve_public_ips(uri.hostname).first
      raise FetchError, 'unsafe destination' unless ip

      body = String.new(encoding: Encoding::BINARY)
      response = Net::HTTP.start(uri.hostname, uri.port, nil, ipaddr: ip,
                                                              use_ssl: uri.scheme == 'https', open_timeout: 3, read_timeout: 5, write_timeout: 3, max_retries: 0) do |http|
        http.request_get(uri.request_uri, {
                           'User-Agent' => 'DottedLinkPreview/1.0',
                           'Accept' => icon ? 'image/*,*/*;q=0.1' : 'text/html',
                           'Accept-Encoding' => 'identity'
                         }) do |reply|
          next unless reply.is_a?(Net::HTTPSuccess)

          reply.read_body do |chunk|
            body << chunk
            raise FetchError, 'response is too large' if body.bytesize > size
          end
        end
      end

      if response.is_a?(Net::HTTPRedirection)
        location = response['location']
        raise FetchError, 'redirect without a location' if location.blank?

        uri = URI.join(uri.to_s, location)
        next
      end

      raise FetchError, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      content_type = response.content_type
      raise FetchError, 'response is not HTML' if !icon && content_type != 'text/html'

      return [uri.to_s, body, content_type]
    end

    raise FetchError, 'too many redirects'
  rescue URI::InvalidURIError, Surfguard::Unresolvable, Surfguard::Violation,
         SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => e
    raise FetchError, e.message
  end
end
