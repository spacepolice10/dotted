# frozen_string_literal: true

module Bullet::WithNote
  extend ActiveSupport::Concern

  included do
    has_one :note, as: :notable, dependent: :destroy

    scope :with_note, -> { joins(:note) }
  end

  def with_note? = note&.content.present?

  def update_note(attributes, resurface: false)
    transaction do
      next false unless (note || build_note).update(attributes)

      postpone!(pops_on: Date.current) if resurface
      true
    end
  end
end
