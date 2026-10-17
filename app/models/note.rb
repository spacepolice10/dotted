# frozen_string_literal: true

# Rich elaboration belonging to a bullet or another supported owner.
class Note < ApplicationRecord
  belongs_to :notable, polymorphic: true, touch: true

  has_rich_text :content

  def excerpt(length: 180)
    content.to_plain_text.squish.truncate(length)
  end

  validates :notable_id, uniqueness: { scope: :notable_type }
end
