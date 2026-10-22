# frozen_string_literal: true

# Resolves a same-origin @return_to path from declared sources.
#
#   include ReturnToPath
#   return_to_from :param, :referer, only: :new
#   return_to_from :param, only: %i[new create]
module ReturnToPath
  extend ActiveSupport::Concern

  class_methods do
    def return_to_from(*sources, **options)
      before_action(**options) { set_return_to_from(*sources) }
    end
  end

  private

  def set_return_to_from(*sources)
    @return_to = sources.lazy.map { |source| return_to_value_for(source) }.find(&:present?)
  end

  def return_to_value_for(source)
    case source.to_sym
    when :param then permitted_return_to(params[:return_to])
    when :referer then permitted_return_to(request.referer)
    else
      raise ArgumentError, "Unknown return_to source: #{source.inspect}"
    end
  end

  def permitted_return_to(url)
    return if url.blank?

    uri = URI.parse(url.to_s)
    return if uri.host.present? && uri.host != request.host

    [uri.path, uri.query].compact.join('?').presence
  rescue URI::InvalidURIError
    nil
  end
end
