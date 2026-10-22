# frozen_string_literal: true

require 'test_helper'

# rubocop:disable Style/ClassAndModuleChildren
class User::SettingsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.create_settings! unless @user.settings
    @settings = @user.settings
  end

  test 'belongs to user' do
    assert_equal @user, @settings.user
  end

  test 'APPEARANCES lists allowed backgrounds' do
    assert_equal %w[default warm cool nature cheese kazakstans_skyview refurbished tetradka], User::Settings::APPEARANCES
  end

  test 'appearance must be a known preset' do
    @settings.appearance = 'kazakstans_skyview'
    assert_predicate @settings, :valid?

    @settings.appearance = 'unknown'
    assert_not @settings.valid?
    assert_includes @settings.errors[:appearance], 'is not included in the list'
  end
end
# rubocop:enable Style/ClassAndModuleChildren
