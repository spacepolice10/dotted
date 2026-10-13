# frozen_string_literal: true

module ExportDownload
  extend ActiveSupport::Concern

  private

  def download_export_html(template:, filename:)
    html = render_to_string(template: template, layout: 'export', formats: [:html])
    html = absolutize_root_relative_urls(html)

    send_data html,
              filename: filename,
              type: 'text/html; charset=utf-8',
              disposition: 'attachment'
  end

  def absolutize_root_relative_urls(html)
    base = request.base_url
    html.gsub('href="/', "href=\"#{base}/")
        .gsub('src="/', "src=\"#{base}/")
  end
end
