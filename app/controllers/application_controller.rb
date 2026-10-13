# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include RequestForgeryProtection, CurrentTimezone, RequestVariant, Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  etag { Current.user&.id }

  def current_user
    Current.user
  end
end
