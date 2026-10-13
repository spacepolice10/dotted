# frozen_string_literal: true

class PublishedController < ApplicationController
  layout 'public', only: :show

  allow_unauthenticated_access only: ['show']

  def index
    @bullets = Current.user.bullets.published
                      .includes(:published_entity)
                      .preload(:collection, file_attachment: :blob)
                      .order(published_entities: { published_at: :desc })
  end

  def show
    entity = PublishedEntity.find_by!(code: params[:code])
    @bullet = entity.publishable
    raise ActiveRecord::RecordNotFound unless @bullet.is_a?(Bullet)
  end
end
