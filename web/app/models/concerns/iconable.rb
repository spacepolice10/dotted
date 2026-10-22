# frozen_string_literal: true

module Iconable
  extend ActiveSupport::Concern

  ICON_MAPPINGS = %w[
    folder briefcase house books lightbulb heart target memo art
    cooking airplane muscle cart music
  ].freeze

  DEFAULT_ICON = 'folder'

  included do
    validates :icon, inclusion: { in: ICON_MAPPINGS }, allow_nil: true
  end

  def icon_name
    icon.in?(ICON_MAPPINGS) ? icon : DEFAULT_ICON
  end
end
