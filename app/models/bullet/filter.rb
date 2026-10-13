# frozen_string_literal: true

# Query-param filter for the Daylog feed: optional collection tag and pops_on range.
class Bullet::Filter
  class Error < StandardError; end

  attr_reader :user, :collection, :from, :to

  def self.from_params(params, user:)
    new(params, user: user)
  end

  def initialize(params, user:)
    @user = user
    @collection = resolve_collection(params[:collection])
    @from = parse_date(params[:from])
    @to = parse_date(params[:to])
    @completed = ActiveModel::Type::Boolean.new.cast(params[:completed])
    raise Error if @from && @to && @from > @to
  end

  def completed?
    !!@completed
  end

  def empty?
    to_params.empty?
  end

  def name
    return 'Completed' if completed?
    return collection.name if collection
    return 'Upcoming' if upcoming_only?

    'Daylog'
  end

  def upcoming_only?
    !completed? && from == Date.current + 1 && to.nil? && collection.nil?
  end

  def includes_date?(date)
    !completed? && (from.nil? || from <= date) && (to.nil? || to >= date)
  end

  def to_params
    {}.tap do |params|
      params[:collection] = collection.name if collection
      params[:from] = from.iso8601 if from
      params[:to] = to.iso8601 if to
      params[:completed] = true if completed?
    end
  end

  def filtered(relation)
    relation = completed? ? relation.done : relation.not_done
    relation = filter_by_date(relation) unless skip_default_date_window?
    relation = relation.tagged_with(collection) if collection
    relation
  end

  private

  # Completed bullets include future-dated items unless an explicit date
  # range narrows the feed.
  def skip_default_date_window?
    completed? && from.nil? && to.nil?
  end

  def resolve_collection(name)
    return if name.blank?

    user.collections.find_by(name: name.to_s.strip.downcase) || raise(Error)
  end

  def parse_date(value)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    raise Error
  end

  def filter_by_date(relation)
    if from.nil? && to.nil?
      relation.current
    elsif from && to
      relation.where(pops_on: from..to)
    elsif from
      relation.where(pops_on: from..)
    else
      relation.where(pops_on: ..to)
    end
  end
end
