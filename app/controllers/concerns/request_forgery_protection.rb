# frozen_string_literal: true

module RequestForgeryProtection
  extend ActiveSupport::Concern

  included do
    protect_from_forgery with: :exception
  end

  private

  def verified_request?
    super || allowed_browserless_request?
  end

  def allowed_browserless_request?
    request.format.json? && request.headers['Sec-Fetch-Site'].blank?
  end
end
