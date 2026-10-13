# frozen_string_literal: true

class Search::GlobalRequest
  LIMIT = 20
  FUZZY_MATCH_THRESHOLD = 4
  FTS5_CANDIDATE_LIMIT = 100
  FUZZY_SCAN_LIMIT = 200

  class << self
    def call(user:, query:, limit: LIMIT)
      new(user:, query:, limit:).call
    end
  end

  def initialize(user:, query:, limit: LIMIT)
    @user = user
    @query = query.to_s.strip
    @limit = limit
    @terms = Search::TermBuilder.normalize(@query)
  end

  def call
    return [] if @query.blank?

    records = Search::Record.search(user: @user, query: @query, limit: FTS5_CANDIDATE_LIMIT).to_a
    records = apply_fuzzy_fallback(records) if records.size < FUZZY_MATCH_THRESHOLD

    build_results(records)
  end

  private

  def apply_fuzzy_fallback(records)
    existing_ids = records.map(&:id).to_set

    supplemental = Search::Record.where(user_id: @user.id)
                                 .where.not(id: existing_ids.to_a)
                                 .limit(FUZZY_SCAN_LIMIT)
                                 .select { |record| fuzzy_match?(record) }

    records + supplemental
  end

  def fuzzy_match?(record)
    haystack = [record.search_name, record.search_body].join(' ').downcase
    haystack_words = haystack.split(/\s+/)

    @terms.all? do |term|
      haystack.include?(term) ||
        (term.length >= 3 && haystack_words.any? { |word| DidYouMean::Levenshtein.distance(word, term) <= 1 })
    end
  end

  def build_results(records)
    ranked = records.sort_by { |record| rank(record) }.first(@limit)
    preload_searchables(ranked)

    ranked.filter_map(&:searchable)
  end

  def rank(record)
    ranking = record.attributes['fts5_rank'].to_f
    name = record.search_name.to_s.downcase
    body = record.search_body.to_s.downcase

    @terms.each do |term|
      ranking -= 5 if name == term
      ranking -= 3 if name.start_with?(term)
      ranking -= 1 if body.include?(term)
    end

    age_days = (Time.current - record.updated_at) / 1.day
    ranking -= [3 - age_days / 30.0, 0].max

    ranking
  end

  def preload_searchables(records)
    records.group_by(&:searchable_type).each_value do |type_records|
      includes = type_records.first.searchable&.class&.search_preload || []
      next if includes.empty?

      ActiveRecord::Associations::Preloader.new(
        records: type_records,
        associations: { searchable: includes }
      ).call
    end
  end
end
