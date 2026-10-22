# frozen_string_literal: true

module Search
  # Expands small spelling mistakes against indexed words, then retrieves via FTS.
  class TypeSearchRequest
    CANDIDATE_LIMITS = 100
    MAXIMUM_TERM_NUMBER = 8
    MAXIMUM_TERM_LENGTH = 32
    MAXIMUM_CORRECTIONS = 16

    def self.call(user:, search_term:)
      new(user:, search_term:).call
    end

    def initialize(user:, search_term:)
      @user = user
      @term_list = Search::TermBuilder.term_list(search_term).map { |term| vocabulary_term(term) }
    end

    def call
      return Search::Record.none if @term_list.empty? || @term_list.size > MAXIMUM_TERM_NUMBER

      expressions = @term_list.map do |term|
        alternatives = ["\"#{term}\"*"]
        corrections(term).each { |word| alternatives << "\"#{word}\"" } if term.length.between?(3, MAXIMUM_TERM_LENGTH)
        "(#{alternatives.join(' OR ')})"
      end

      Search::Record.search_expression(user: @user, expression: expressions.join(' AND '), limits: CANDIDATE_LIMITS)
    end

    private

    # Match unicode61's Latin accent folding while preserving other scripts.
    def vocabulary_term(term)
      term.unicode_normalize(:nfd).gsub(/(\p{Latin})\p{M}+/, '\1').unicode_normalize(:nfc)
    end

    # GLOB's single-character wildcard covers a substitution or missing letter;
    # deleting a character from the search term covers an extra letter. Swapped pairs
    # cover adjacent transpositions. No note bodies are read.
    def corrections(term)
      patterns = edit_patterns(term)
      condition = patterns.map { 'vocabulary.term GLOB ?' }.join(' OR ')
      sqlite_request = Search::Record.sanitize_sql_array([correction_sql(condition), *patterns, @user.id,
                                                          MAXIMUM_CORRECTIONS])
      Search::Record.connection.select_values(sqlite_request)
    end

    def correction_sql(condition)
      <<~SQL
        SELECT vocabulary.term FROM search_vocabulary AS vocabulary
        WHERE (#{condition})
          AND EXISTS (
            SELECT 1 FROM search_records_fts5 JOIN search_records
              ON search_records.id = search_records_fts5.rowid
            WHERE search_records_fts5 MATCH ('"' || vocabulary.term || '"')
              AND search_records.user_id = ?
          )
        LIMIT ?
      SQL
    end

    def edit_patterns(term)
      patterns = []
      term.length.times do |index|
        prefix = term[0...index]
        suffix = term[(index + 1)..]
        patterns << "#{prefix}?#{suffix}"
        patterns << "#{prefix}#{suffix}"
      end
      (0..term.length).each { |index| patterns << "#{term[0...index]}?#{term[index..]}" }
      (patterns + transpositions(term)).uniq
    end

    def transpositions(term)
      term.chars.each_cons(2).with_index.map do |(left, right), index|
        "#{term[0...index]}#{right}#{left}#{term[(index + 2)..]}"
      end
    end
  end
end
