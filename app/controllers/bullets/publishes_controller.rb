# frozen_string_literal: true

module Bullets
  class PublishesController < ApplicationController
    include PrepareBullets

    before_action :prepare_bullets

    def create
      Bullet.transaction do
        @bullets.lock.find_each(&:publish!)
      end
      @bullets.each(&:reload)
      preload_bullet_collections

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to published_path(@bullets.first.public_code) }
        format.json { render 'bullets/bulk' }
      end
    rescue ActiveRecord::RecordInvalid => e
      respond_with_failed_bullet(e)
    end

    def destroy
      Bullet.transaction do
        @bullets.lock.find_each(&:unpublish!)
      end
      @bullets.each(&:reload)
      preload_bullet_collections

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to root_path }
        format.json { render 'bullets/bulk' }
      end
    rescue ActiveRecord::RecordInvalid => e
      respond_with_failed_bullet(e)
    end
  end
end
