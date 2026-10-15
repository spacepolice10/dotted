# frozen_string_literal: true

class Bookmark::UnfurlJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  def perform(bookmark)
    return if bookmark.unfurled_at? && (bookmark.favicon.attached? || bookmark.icon_link.blank?)

    bookmark.update!(**unfurler_of(bookmark.link).call, unfurled_at: Time.current)
  rescue Bookmark::Unfurler::FetchError
    # Keep the basic chip when a page cannot be fetched.
  end

  private

  def unfurler_of(link)
    Bookmark::Unfurler.new(link)
  end
end
