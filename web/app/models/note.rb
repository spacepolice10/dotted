# frozen_string_literal: true

# Rich elaboration belonging to a bullet or another supported owner.
class Note < ApplicationRecord
  belongs_to :notable, polymorphic: true, touch: true

  has_rich_text :content

  validates :notable_id, uniqueness: { scope: :notable_type }
end
