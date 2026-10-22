# frozen_string_literal: true

# Per-user settings. One row per user, created automatically.
#
class User::Settings < ApplicationRecord
  APPEARANCES = %w[default warm cool nature cheese kazakstans_skyview refurbished tetradka].freeze

  belongs_to :user

  validates :appearance, inclusion: { in: APPEARANCES }
end
