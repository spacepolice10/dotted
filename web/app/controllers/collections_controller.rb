# frozen_string_literal: true

class CollectionsController < ApplicationController
  include PrepareBullets, ReturnToPath

  before_action :set_collection, only: %i[show edit update destroy]
  before_action :prepare_collect_context, only: %i[new create]
  return_to_from :param, only: %i[new create]

  def index
    @collections = Current.user.collections.order(:name)
  end

  def new
    @collection = Current.user.collections.build
  end

  def create
    @collection = Current.user.collections.build(collection_params)
    @collection.save_and_collect!(bullets: @bullets || Bullet.none)

    destination = @bullet_ids.present? ? collect_return_path : collections_path
    respond_to do |format|
      format.html { redirect_to destination, notice: 'Collection created' }
      format.json { render :show, status: :created, location: @collection }
    end
  rescue ActiveRecord::RecordInvalid => e
    if e.record == @collection
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @collection.errors.to_hash, status: :unprocessable_entity }
      end
    else
      @failed_bullet = e.record
      respond_to do |format|
        format.turbo_stream { render 'bullets/collects/create', status: :unprocessable_entity }
        format.html do
          redirect_back fallback_location: search_path, alert: e.record.errors.full_messages.to_sentence
        end
        format.json { render json: e.record.errors.to_hash, status: :unprocessable_entity }
      end
    end
  end

  def show
    @bullets = @collection.unsorted_bullets
    @parked_items = @collection.parked_items
  end

  def edit; end

  def update
    if @collection.update(collection_params)
      respond_to do |format|
        format.html { redirect_to collection_path(@collection), notice: 'Collection updated' }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @collection.errors.to_hash, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @collection.destroy
    respond_to do |format|
      format.html { redirect_to search_path, notice: 'Collection deleted' }
      format.json { head :no_content }
    end
  end

  private

  def set_collection
    @collection = Current.user.collections.find(params[:id])
  end

  def collection_params
    params.require(:collection).permit(:name, :colour, :icon, :description, :favorite)
  end

  def prepare_collect_context
    @bullet_ids = params[:bullet_ids].to_s.presence
    return if @bullet_ids.blank?

    @bullets = prepare_bullets_from(@bullet_ids)
  end

  def collect_return_path
    @return_to.presence || collection_path(@collection)
  end
end
