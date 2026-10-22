# frozen_string_literal: true

module Search::TermBuilder
  extend self

  def build(search_term)
    term_list = self.term_list(search_term)
    return if term_list.empty?

    term_list.map { |term| "\"#{term}\"*" }.join(' AND ')
  end

  def term_list(search_term)
    normalize(search_term).filter_map { |term| escape(term).presence }
  end

  def normalize(search_term)
    search_term.to_s.downcase.gsub(/[^\p{L}\p{N}\s"]/u, ' ').split(/\s+/).grep(/\S/)
  end

  private

  def escape(term)
    term.delete('"')
  end
end
