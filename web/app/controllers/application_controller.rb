# frozen_string_literal: true

class ApplicationController < ActionController::Base
  NATIVE_TABS_USER_AGENT = 'Dotted Native Tabs;'

  include RequestForgeryProtection, CurrentTimezone, RequestVariant, Authentication
  helper_method :native_tabs?
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  etag { Current.user&.id }
  etag { native_tabs? }

  def native_tabs?
    request.user_agent.to_s.include?(NATIVE_TABS_USER_AGENT)
  end

  def current_user
    Current.user
  end
end
