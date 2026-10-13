# frozen_string_literal: true

class Search::Highlight
  class << self
    def call(html, query)
      words = Search::TermBuilder.terms(query)
      return html if words.empty?

      pattern = pattern_of(words)
      fragment = Loofah.html5_fragment(html.to_s)
      changed = false

      fragment.xpath('.//text()').to_a.each do |node|
        next if node.content.blank?
        next unless node.content.match?(pattern)
        next if node.ancestors.any? { |ancestor| ancestor.element? && ancestor.name.in?(%w[mark script style]) }

        node.replace(marked(node.content, pattern))
        changed = true
      end

      changed ? fragment.to_html.html_safe : html
    end

    private

    def pattern_of(words)
      alternation = words.sort_by { |word| -word.length }.map { |word| Regexp.escape(word) }.join('|')
      /(?<![\p{L}\p{N}])(?:#{alternation})[\p{L}\p{N}]*/i
    end

    def marked(text, pattern)
      cursor = 0
      pieces = +''

      text.scan(pattern) do
        last_matched_from_thread = Regexp.last_match
        pieces << ERB::Util.html_escape(text[cursor...last_matched_from_thread.begin(0)])
        pieces << %(<mark class="search--term decoration--circle decoration-colour--sky">#{ERB::Util.html_escape(last_matched_from_thread[0])}</mark>)
        cursor = last_matched_from_thread.end(0)
      end

      pieces << ERB::Util.html_escape(text[cursor..])
      pieces
    end
  end
end
