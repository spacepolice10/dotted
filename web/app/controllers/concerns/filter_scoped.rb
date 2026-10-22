# frozen_string_literal: true

module FilterScoped
  extend ActiveSupport::Concern

  included do
    rescue_from Bullet::Filter::Error, with: :render_filter_not_found
  end

  private

  def set_filter
    @filter = Bullet::Filter.from_params(params, user: Current.user)
  end

  def set_timeline
    @timeline = Timeline.new(Current.user, filter: @filter)
  end

  def render_filter_not_found
    head :not_found
  end
end
