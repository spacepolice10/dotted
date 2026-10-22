# frozen_string_literal: true

module Collection::NameMatching
  extend ActiveSupport::Concern

  included do
    scope :matching_name, lambda { |search_term|
      sanitized = sanitize_sql_like(search_term.to_s.strip.downcase).presence

      sanitized ? where('LOWER(collections.name) LIKE ?', "#{sanitized}%") : all
    }
  end
end
