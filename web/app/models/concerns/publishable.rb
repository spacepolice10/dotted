# frozen_string_literal: true

module Publishable
  extend ActiveSupport::Concern

  included do
    has_one :published_entity, as: :publishable, dependent: :destroy

    scope :published, -> { joins(:published_entity) }
  end

  def published?
    published_entity.present?
  end

  def publish!
    return if published?

    create_published_entity!(user: user)
  end

  def unpublish!
    return unless published?

    published_entity.destroy!
  end

  def public_code
    published_entity&.code
  end
end
