# frozen_string_literal: true

class Search::GlobalRequest
  LIMITS = 20
  MATCHES_THRESHOLD = 2
  FTS5_CANDIDATE_LIMITS = 100

  class << self
    def call(user:, search_term:)
      new(user:, search_term:).call
    end
  end

  def initialize(user:, search_term:)
    @user = user
    @search_term = search_term.to_s.strip
    @term_list = Search::TermBuilder.normalize(@search_term)
  end

  def call
    return [] if @search_term.blank?

    records = Search::Record.search(user: @user, search_term: @search_term, limits: FTS5_CANDIDATE_LIMITS).to_a
    records = typo_fallback_search(records) if records.size < MATCHES_THRESHOLD

    build_results(records)
  end

  private

  def typo_fallback_search(records)
    supplemental = Search::TypeSearchRequest.call(user: @user, search_term: @search_term)
    (records + supplemental.to_a).uniq(&:id)
  end

  def build_results(records)
    ranked = records.sort_by { |record| rank(record) }.first(LIMITS)
    preload_searchables(ranked)

    ranked.filter_map(&:searchable)
  end

  def rank(record)
    ranking = record.attributes['fts5_rank'].to_f
    name = record.search_name.to_s.downcase
    body = record.search_body.to_s.downcase

    @term_list.each do |term|
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
