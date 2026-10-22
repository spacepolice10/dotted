# frozen_string_literal: true

# Search content backed by the full-text index.
class Search::Record < ApplicationRecord
  SEARCH_CONTENT_SIZE = 32.kilobytes

  belongs_to :user
  belongs_to :searchable, polymorphic: true

  validates :user_id, :searchable_type, :searchable_id, presence: true

  class << self
    def search(user:, search_term:, limits: 50)
      Sqlite.search(user:, search_term:, limits:)
    end

    def search_expression(user:, expression:, limits:)
      Sqlite.search_expression(user:, expression:, limits:)
    end

    def matching(expression) = Sqlite.matching(expression)
    def ensure_fts5_triggers! = Sqlite.ensure_fts5_triggers!
    def install_fts5_triggers! = Sqlite.install_fts5_triggers!
    def rebuild_fts5_index! = Sqlite.rebuild_fts5_index!
    def fts5_trigger_installed? = Sqlite.fts5_trigger_installed?

    def upsert!(attributes)
      upsert(
        attributes,
        unique_by: %i[user_id searchable_type searchable_id]
      )
    end
  end
end
