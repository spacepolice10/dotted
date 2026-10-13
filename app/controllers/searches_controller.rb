# frozen_string_literal: true

class SearchesController < ApplicationController
  # Navigation only. Searching lives on the results route.
  def show
    @collections = Current.user.collections.order(:name)
    @attachments_count = User::Attachments.new(Current.user).attachments.count
    @completed_count = Current.user.bullets.done.count
    @collections_count = Current.user.collections.count
    @upcoming_count = Current.user.bullets.upcoming.count
  end

  def results
    @q = params[:q].to_s.strip

    # A blank query is the empty state, not an error: the card shows at most
    # ten rows. Search::GlobalRequest::LIMIT stays the global cap, so there is
    # no turbo_stream format to negotiate here.
    @entries = if @q.present?
                 Search::GlobalRequest.call(user: Current.user, query: @q, limit: 10)
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
