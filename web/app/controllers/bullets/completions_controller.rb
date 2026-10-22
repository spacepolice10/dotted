# frozen_string_literal: true

module Bullets
  class CompletionsController < ApplicationController
    include PrepareBullets

    before_action :prepare_bullets

    def create
      Bullet.transaction do
        @bullets.lock.find_each(&:complete!)
      end
      @bullets.each(&:reload)
      preload_bullet_collections

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: bullets_path }
        format.json { render 'bullets/bulk' }
      end
    rescue ActiveRecord::RecordInvalid => e
      respond_with_failed_bullet(e)
    end

    def destroy
      Bullet.transaction do
        @bullets.lock.find_each(&:uncomplete!)
      end
      @bullets.each(&:reload)
      preload_bullet_collections

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: bullets_path }
        format.json { render 'bullets/bulk' }
      end
    rescue ActiveRecord::RecordInvalid => e
      respond_with_failed_bullet(e)
    end
  end
end
