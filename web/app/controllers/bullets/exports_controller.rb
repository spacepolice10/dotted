# frozen_string_literal: true

module Bullets
  class ExportsController < ApplicationController
    include ExportDownload, FilterScoped

    before_action :set_filter
    before_action :set_timeline

    def show
      @bullets = @timeline.filtered.by_date.preload(:rich_text_body, file_attachment: :blob)

      download_export_html(
        template: 'bullets/exports/show',
        filename: export_filename
      )
    end

    private

    def export_filename
      slug = @filter.name.parameterize
      "dotted-#{slug}-export-#{Date.current.iso8601}.html"
    end
  end
end
