# frozen_string_literal: true

require "test_helper"

class ColourableTest < ActiveSupport::TestCase
  test "mint maps to model-color-9 tokens" do
    assert_equal "var(--model-color-9)", Colourable.colour_variable_of("mint")
    assert_equal "var(--model-color-9-bg)", Colourable.colour_bg_variable_of("mint")
  end

  test "mint is a valid colourable value" do
    assert_includes Colourable::COLOUR_MAPPINGS.keys, "mint"
  end
end
