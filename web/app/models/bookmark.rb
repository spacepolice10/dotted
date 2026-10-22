# frozen_string_literal: true

class Bookmark < ApplicationRecord
  include ActionText::Attachable

  CONTENT_TYPE = 'application/vnd.dotted.link-chip'

  belongs_to :bullet
  has_one_attached :favicon

  normalizes :link, with: ->(link) { link.strip }

  validates :link, presence: true, uniqueness: { scope: :bullet_id }
  validate do
    errors.add(:link, 'must be an HTTP or HTTPS URL') unless Bookmark.valid_url?(link)
  end

  after_create_commit { Bookmark::UnfurlJob.perform_later(self) unless unfurled_at? }

  def self.valid_url?(value)
    uri = URI.parse(value.to_s)
    value if uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?
  rescue URI::InvalidURIError
    nil
  end

  def attachable_content_type
    CONTENT_TYPE
  end

  def attachable_text_representation(_caption = nil)
    "#{title.presence || URI.parse(link).host} (#{link})"
  end

  def to_attachable_partial_path
    'bookmarks/chip'
  end
end
