# frozen_string_literal: true

module Bullet::Searchable
  extend ActiveSupport::Concern
  include ::Searchable

  # Runs after ::Searchable's included block, so the class_attribute exists.
  included do
    self.search_preload = %i[collection rich_text_body published_entity]
  end

  def searchable?
    !done?
  end

  def search_name
    name.to_s.truncate(255)
  end

  def search_body
    [body_as_text, filename].compact.join(' ')
  end

  # Search results render the whole rich body so marks land inside Lexxy's tags.
  # File-only bullets have no body but are indexed by filename, so fall back to it.
  def search_result_body
    body.to_s.strip.presence || filename.presence || name
  end

  def search_result_icon = marker_icon.to_s.dasherize

  def search_result_type = self.class.name.titleize
end
