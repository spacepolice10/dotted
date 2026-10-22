# frozen_string_literal: true

module Bullet::Bookmarkable
  extend ActiveSupport::Concern

  URLS_PATTERN = %r{(https?://[^\s<>"']+)}i
  TRAILING_PUNCTUATION = /[.,;:!?\])]+\z/

  included do
    has_many :bookmarks, dependent: :destroy

    before_save :mark_urls_changed
    after_save :sync_urls, if: :urls_changed?

    validate :validate_urls

    scope :with_urls, -> { joins(:bookmarks).distinct }
  end

  private

  def sync_urls
    rich_text = rich_text_body
    return unless rich_text

    fragment = Nokogiri::HTML.fragment(rich_text.body.to_html)

    fragment.xpath('.//text()').each do |node|
      next if node.ancestors.any? do |ancestor|
        %w[a action-text-attachment script style code pre].include?(ancestor.name)
      end
      next unless node.text.match?(URLS_PATTERN)

      node.replace(node.text.split(URLS_PATTERN).map do |text|
        url = text.sub(TRAILING_PUNCTUATION, '')
        next ERB::Util.html_escape(text) unless Bookmark.valid_url?(url)

        anchor = fragment.document.create_element('a', url, href: url)
        anchor.to_html + ERB::Util.html_escape(text.delete_prefix(url))
      end.join)
    end

    existing_bookmarks = bookmarks.scope.index_by(&:link)
    urls = []

    fragment.css("a[href], action-text-attachment[content-type='#{Bookmark::CONTENT_TYPE}']").each do |node|
      next if node.ancestors.any? { |ancestor| ancestor.name == 'action-text-attachment' }

      source_bookmark = (Bookmark.from_attachable_sgid(node['sgid']) if node.name == 'action-text-attachment')
      url = source_bookmark&.link || Bookmark.valid_url?(node['href'])
      next unless url

      bookmark = existing_bookmarks[url] ||= bookmarks.create!(link: url) do |record|
        record.assign_attributes(source_bookmark.slice(:title, :icon_link, :unfurled_at)) if source_bookmark
      end
      if source_bookmark&.favicon&.attached? && !bookmark.favicon.attached?
        bookmark.favicon.attach(source_bookmark.favicon.blob)
      end
      urls << url

      if source_bookmark
        node['sgid'] = bookmark.attachable_sgid
      elsif node.text.strip == url
        node.replace(ActionText::Attachment.from_attachable(bookmark).to_html)
      end
    end

    bookmarks.where.not(link: urls.uniq).destroy_all
    rich_text.body = fragment.to_html
    rich_text.save! if rich_text.changed?
  end

  def mark_urls_changed
    @urls_changed = rich_text_body&.will_save_change_to_body?
  end

  def urls_changed?
    @urls_changed
  end

  def validate_urls
    return unless rich_text_body&.will_save_change_to_body?

    fragment = Nokogiri::HTML.fragment(rich_text_body&.body&.to_html.to_s)
    fragment.css('action-text-attachment').each do |node|
      next unless node['content-type'] == Bookmark::CONTENT_TYPE

      valid = node['sgid'].present? && node['content'].nil? &&
              Bookmark.from_attachable_sgid(node['sgid'])&.bullet&.user_id == user_id
      errors.add(:body, 'contains an invalid link chip') unless valid
    rescue ActiveRecord::RecordNotFound
      errors.add(:body, 'contains an invalid link chip')
    end
  end
end
