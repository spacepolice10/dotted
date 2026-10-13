# frozen_string_literal: true

# Sets `request.variant = :mobile` for phone UAs so `+mobile` templates can resolve.
module RequestVariant
  extend ActiveSupport::Concern

  included do
    before_action :set_variant
  end

  private

  def set_variant
    request.variant = :mobile if request.user_agent&.match?(/Mobile|Android|iPhone/i)
  end
end
