# frozen_string_literal: true

module Collections
  class ItemsController < ApplicationController
    before_action :set_collection

    def update
      @collection.move_bullet!(bullet_id: params[:bullet_id], lane: params.require(:lane), before_id: params[:before_id])
      @bullets = @collection.unsorted_bullets
      @parked_items = @collection.parked_items

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to collection_path(@collection), status: :see_other }
      end
    rescue ArgumentError, ActionController::ParameterMissing
      head :unprocessable_entity
    end

    def move
      ids = params.require(:bullet_ids).to_s.split(',').map { |id| Integer(id, 10) }.uniq
      raise ArgumentError, 'No bullets selected' if ids.empty?

      @collection.move_bullets!(bullet_ids: ids, lane: params.require(:lane))
      @bullets = @collection.unsorted_bullets
      @parked_items = @collection.parked_items

      respond_to do |format|
        format.turbo_stream { render :update }
        format.html { redirect_to collection_path(@collection), status: :see_other }
      end
    rescue ArgumentError, ActionController::ParameterMissing
      head :unprocessable_entity
    end

    private

    def set_collection
      @collection = Current.user.collections.find(params[:collection_id])
    end
  end
end
