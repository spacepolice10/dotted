# frozen_string_literal: true

class Search::Record < ApplicationRecord
  include Search::Record::Sqlite

  SEARCH_CONTENT_SIZE = 32.kilobytes

  belongs_to :user
  belongs_to :searchable, polymorphic: true

  validates :user_id, :searchable_type, :searchable_id, presence: true

  class << self
    def upsert!(attributes)
      record = find_by(
        searchable_type: attributes[:searchable_type],
        searchable_id: attributes[:searchable_id]
      )

      if record
        record.update!(attributes)
        record
      else
        create!(attributes)
      end
    end
  end
end
