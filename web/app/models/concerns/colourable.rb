# frozen_string_literal: true

module Colourable
  extend ActiveSupport::Concern

  COLOUR_MAPPINGS = {
    'violet' => 'var(--model-color-1)',
    'cobalt' => 'var(--model-color-2)',
    'teal' => 'var(--model-color-3)',
    'emerald' => 'var(--model-color-4)',
    'gold' => 'var(--model-color-5)',
    'vermillion' => 'var(--model-color-6)',
    'magenta' => 'var(--model-color-7)',
    'mint' => 'var(--model-color-9)'
  }.freeze

  included do
    validates :colour, inclusion: { in: COLOUR_MAPPINGS.keys }, allow_nil: true
  end

  def self.colour_variable_of(colour)
    COLOUR_MAPPINGS[colour]
  end

  def self.colour_bg_variable_of(colour)
    colour_variable_of(colour)&.sub(/\)\z/, '-bg)')
  end
end
