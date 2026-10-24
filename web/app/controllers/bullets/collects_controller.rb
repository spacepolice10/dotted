# frozen_string_literal: true

module Bullets
  class CollectsController < ApplicationController
    include PrepareBullets, ReturnToPath

    before_action :prepare_bullets
    return_to_from :param, :referer, only: :new

    def new
      @collects_search_term = params[:search_term].to_s.strip.presence
      @collections = Current.user.collections
                            .matching_name(params[:search_term])
                            .order(:name)
                            .limit(10)
      @collected_collection_ids = collected_collection_ids

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    def create
      collection_id = params.require(:collection_id)
      @collection = Current.user.collections.find(collection_id)
      lane = params[:lane].presence || 'unsorted'
      raise ArgumentError, 'Unknown lane' unless lane.in?(%w[unsorted parked])

      Bullet.transaction do
        @bullets = @bullets.lock
        @bullets.each do |bullet|
          bullet.collect!(collection_id: collection_id)
          @collection.move_bullet!(bullet_id: bullet.id, lane: lane)
        end
      end
      @bullet_ids = params[:bullet_ids].to_s
      @collected_collection_ids = collected_collection_ids

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: bullets_path }
        format.json { render 'bullets/bulk' }
      end
    rescue ActiveRecord::RecordInvalid => e
      respond_with_failed_bullet(e)
    rescue ArgumentError
      head :unprocessable_entity
    end

    private

    # A checkmark means every selected bullet is in this collection.
    def collected_collection_ids
      bullet_ids = @bullets.pluck(:id)
      return [] if bullet_ids.empty?

      @bullets.where.not(collection_id: nil)
              .group(:collection_id)
              .having('COUNT(*) = ?', bullet_ids.size)
              .pluck(:collection_id)
    end
  end
end
