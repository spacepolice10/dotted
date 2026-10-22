# frozen_string_literal: true

module ActivityTrackable
  extend ActiveSupport::Concern

  included do
    has_many :activities, as: :subject
  end

  def record_activity!(action, metadata: {})
    activities.create!(user: user, action: action, metadata: metadata)
  end
end
