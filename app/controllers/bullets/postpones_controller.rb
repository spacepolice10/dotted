# frozen_string_literal: true

module Bullets
  class PostponesController < ApplicationController
    include PrepareBullets

    before_action :prepare_bullets, only: %i[new create]

    def new
      today = Date.current

      @postpone_options = [
        { id: :today,         icon: 'arrow-up',        name: 'Today',        pops_on: today },
        { id: :tomorrow,      icon: 'arrow-right',     name: 'Tomorrow',     pops_on: today + 1.day },
        { id: :next_monday,   icon: 'calendar-repeat', name: 'Next week',    pops_on: today.next_occurring(:monday) },
        { id: :next_weekend,  icon: 'calendar-repeat', name: 'Next weekend', pops_on: today.next_occurring(:saturday) },
        { id: :next_month,    icon: 'calendar',        name: 'Next month',   pops_on: (today + 1.month).beginning_of_month }
      ]
    end

    def create
      pops_on = parse_pops_on

      Bullet.transaction do
        @bullets.lock.find_each { |bullet| bullet.postpone!(pops_on: pops_on) }
      end
      @bullets.each(&:reload)
      preload_bullet_collections

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: bullets_path }
        format.json { render 'bullets/bulk' }
      end
    rescue ActionController::ParameterMissing, ArgumentError
      @failed_bullet = @bullets&.first
      respond_to do |format|
        format.turbo_stream { render :create, status: :unprocessable_entity }
        format.html { redirect_back fallback_location: bullets_path, alert: 'Invalid date' }
        format.json { render json: { pops_on: ['is invalid'] }, status: :unprocessable_entity }
      end
    rescue ActiveRecord::RecordInvalid => e
      respond_with_failed_bullet(e)
    end

    private

    def parse_pops_on
      Date.iso8601(params.require(:pops_on).to_s)
    end
  end
end
