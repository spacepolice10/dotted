# frozen_string_literal: true

class SearchesController < ApplicationController
  # Navigation only. Searching lives on the results route.
  def show
    @favorite_collections = Current.user.collections.favorites.order(:name)
  end

  def results
    @search_term = params[:search_term].to_s.strip

    # HTML serves the page and its results frame; Turbo Streams update the dialog.
    @entries = if @search_term.present?
                 Search::GlobalRequest.call(user: Current.user, search_term: @search_term)
               else
                 Search::Selection.in_menu(Current.user).filter_map(&:searchable)
               end

    respond_to do |format|
      format.html
      format.turbo_stream
      format.json
    end
  end
end
