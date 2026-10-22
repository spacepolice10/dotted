# frozen_string_literal: true

require 'test_helper'

class SessionMailerTest < ActionMailer::TestCase
  test 'login_code' do
    user = users(:one)
    code = 'ABC123'
    mail = SessionMailer.login_code(user, code)

    assert_equal 'Your login code', mail.subject
    assert_equal [user.email_address], mail.to
    assert_match code, mail.body.encoded
    assert_match '15 minutes', mail.body.encoded
  end
end
