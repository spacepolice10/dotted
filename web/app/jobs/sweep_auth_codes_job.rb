# frozen_string_literal: true

class SweepAuthCodesJob < ApplicationJob
  def perform
    AuthCode.sweep
  end
end
