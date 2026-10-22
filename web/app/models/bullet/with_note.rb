# frozen_string_literal: true

module Bullet::WithNote
  extend ActiveSupport::Concern

  included do
    has_one :note, as: :notable, dependent: :destroy

    scope :with_note, -> { joins(:note) }
  end

  def with_note? = note&.content.present?

  def update_note(attributes)
    transaction do
      next false unless (note || build_note).update(attributes)

      resurface!
      true
    end
  end
end
