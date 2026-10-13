# frozen_string_literal: true

module Search::TermBuilder
  extend self

  def build(query)
    words = terms(query)
    return if words.empty?

    words.map { |term| "\"#{term}\"*" }.join(' AND ')
  end

  def terms(query)
    normalize(query).filter_map { |term| escape(term).presence }
  end

  def normalize(query)
    query.to_s.downcase.gsub(/[^\p{L}\p{N}\s"]/u, ' ').split(/\s+/).grep(/\S/)
  end

  private

  def escape(term)
    term.delete('"')
  end
end
