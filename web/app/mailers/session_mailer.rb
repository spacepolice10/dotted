# frozen_string_literal: true

class SessionMailer < ApplicationMailer
  def login_code(user, code)
    @code = code
    mail to: user.email_address, subject: 'Your login code'
  end
end
