# frozen_string_literal: true

module Searches
  class SelectionsController < ApplicationController
    def create
      searchable = find_searchable!(params.require(:searchable_type), params.require(:searchable_id))

      Search::Selection.record!(user: Current.user, searchable:)

      head :no_content
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    private

    # Resolves through the registered searchables rather than a hand-maintained
    # whitelist, so a new searchable needs no edit here. Scoped to the current
    # user, so a valid id belonging to someone else is still a miss.
    def find_searchable!(type, id)
      model = Searchable.searchable_models.find { |candidate| candidate.name == type }
      raise ActiveRecord::RecordNotFound unless model

      model.find_by!(id:).then do |searchable|
        belongs_to_current_user?(searchable) ? searchable : raise(ActiveRecord::RecordNotFound)
      end
    end

    def belongs_to_current_user?(searchable)
      searchable.respond_to?(:user_id) && searchable.user_id == Current.user.id
    end
  end
end
