# frozen_string_literal: true

class Bullet < ApplicationRecord
  include Completable, Collectable, Postponable, Publishable, Bullet::Pageable,
          Bullet::Searchable, Bullet::Bookmarkable, Bullet::WithNote, Bullet::WithChecklist,
          ActivityTrackable

  belongs_to :user
  belongs_to :collection, optional: true
  has_one :collection_item, dependent: :destroy

  has_rich_text :body

  has_one_attached :file do |attachable|
    attachable.variant :preview, resize_to_limit: [800, 320]
    attachable.variant :display, resize_to_limit: [1600, 1600]
  end

  before_save :capture_filename

  normalizes :client_id, with: ->(value) { value.presence }

  validate :content_is_either_file_or_text
  validate :file_must_be_smaller
  validate :collection_belongs_to_user
  validates :author_name, length: { maximum: 100 }, allow_blank: true
  # Uniqueness enforced by DB index + controller rescue (avoids race toast on :taken).
  validates :client_id, format: { with: /\A[0-9a-f-]{36}\z/i }, allow_nil: true

  before_validation :default_pops_on

  scope :current, -> { where(pops_on: ..Date.current) }
  scope :upcoming, -> { where(pops_on: (Date.current + 1.day)..) }
  scope :unreviewed, -> { where(reviewed_at: nil) }
  scope :with_attachment, -> { joins(:file_attachment) }
  scope :tagged_with, lambda { |collection|
    where(collection_id: collection.id)
  }

  def body_as_text = body.to_plain_text.to_s
  def name = body_as_text.lines.first&.strip.presence || filename.presence || 'Untitled'

  def reset_review!
    update!(reviewed_at: nil)
  end

  def status
    return 'completed' if completed?
    return 'postponed' if last_postponed_at.present?
    return 'published' if published?

    nil
  end

  def marker_icon
    return 'arrow-forward-up' if status == 'postponed'
    return 'link' if status == 'published'
    return 'check' if status == 'completed'

    :circle
  end

  private

  def capture_filename
    self.filename = file.filename.to_s if file.attached?
  end

  def content_is_either_file_or_text
    has_file = file.attached?
    has_text = body_as_text.present? || link_chip_present?
    errors.add(:base, 'Enter text or attach a file, not both') if has_file == has_text
  end

  def link_chip_present?
    html = rich_text_body&.body&.to_html.to_s
    Nokogiri::HTML.fragment(html).at_css("action-text-attachment[content-type='#{Bookmark::CONTENT_TYPE}']").present?
  end

  def file_must_be_smaller
    attachment_size = 5.megabytes
    return unless file.attached? && file.blob.byte_size > attachment_size

    errors.add(:file, "is too large (maximum is #{attachment_size / 1.megabyte} MB)")
  end

  def default_pops_on
    self.pops_on ||= Date.current
  end

  def collection_belongs_to_user
    errors.add(:collection, 'must belong to your account') if collection && collection.user_id != user_id
  end
end
