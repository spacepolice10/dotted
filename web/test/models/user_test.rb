# frozen_string_literal: true

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'downcases and strips email_address' do
    user = User.new(email_address: ' DOWNCASED@EXAMPLE.COM ')
    assert_equal('downcased@example.com', user.email_address)
  end

  test 'has_one :settings' do
    assert_respond_to users(:one), :settings
  end

  test 'creating a user auto-creates settings' do
    user = User.create!(email_address: 'new-settings@example.com')
    assert_not_nil user.settings
    assert_predicate user.settings, :persisted?
  end

  test 'settings! returns the existing row' do
    user = users(:one)
    user.create_settings! unless user.settings
    existing = user.settings
    assert_same existing, user.settings!
  end

  test 'settings! creates the row when missing' do
    user = users(:one)
    user.create_settings! unless user.settings
    user.settings.destroy!
    user.association(:settings).reset
    assert_nil user.settings
    result = user.settings!
    assert_not_nil result
    assert_predicate result, :persisted?
  end
end
