# frozen_string_literal: true

module Collection::NameMatching
  extend ActiveSupport::Concern

  included do
    scope :matching_name, lambda { |query|
      sanitized = sanitize_sql_like(query.to_s.strip.downcase).presence

      sanitized ? where('LOWER(collections.name) LIKE ?', "#{sanitized}%") : all
    }
  end
end
