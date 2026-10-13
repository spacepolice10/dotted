# frozen_string_literal: true

class LandingsController < ApplicationController
  layout 'landing'
  allow_unauthenticated_access
  skip_before_action :set_variant

  content_security_policy do |policy|
    policy.default_src :none
    policy.connect_src :self # Allow same-origin browser tooling in development.
    policy.style_src :self, 'https://fonts.googleapis.com'
    policy.style_src_attr :unsafe_inline # The shared icon helper sets SVG masks inline.
    policy.font_src :self, 'https://fonts.gstatic.com'
    policy.img_src :self
    policy.base_uri :none
    policy.frame_ancestors :none
  end

  def landing; end

  def features; end

  def terminal; end

  def support; end

  def faqs; end

  def once; end
end
