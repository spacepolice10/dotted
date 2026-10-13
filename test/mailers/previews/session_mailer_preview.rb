# frozen_string_literal: true

class SessionMailerPreview < ActionMailer::Preview
  def login_code
    user = User.new(email_address: 'test@example.com')
    code = '123456'
    SessionMailer.login_code(user, code)
  end
end
