# frozen_string_literal: true

class SearchesController < ApplicationController
  # Navigation only. Searching lives on the results route.
  def show
    @collections = Current.user.collections.favorites.order(:name)
    @attachments_count = Current.user.bullets.with_attachment.count
    @completed_count = Current.user.bullets.completed.count
    @collections_count = Current.user.collections.count
    @upcoming_count = Current.user.bullets.upcoming.count
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
