# frozen_string_literal: true

class AuthCode < ApplicationRecord
  EXPIRY = 15.minutes
  CODE_LENGTH = 6

  belongs_to :user

  before_create { self.expires_at = EXPIRY.from_now }

  def self.generate_code
    SecureRandom.alphanumeric(CODE_LENGTH).upcase
  end

  def self.digest(code)
    BCrypt::Password.create(code)
  end

  def self.create_for(user)
    user.auth_codes.delete_all
    code = generate_code
    record = user.auth_codes.create!(code_digest: digest(code))
    [record, code]
  end

  def code_matches?(submitted)
    BCrypt::Password.new(code_digest).is_password?(submitted.to_s.strip.upcase)
  end

  def expired?
    expires_at < Time.current
  end

  def self.sweep
    where(expires_at: ...Time.current).delete_all
  end

  def self.consume!(email:, code:)
    sweep

    user = User.find_by(email_address: email)
    return unless user

    auth_code = user.auth_codes.find { |ac| !ac.expired? && ac.code_matches?(code) }
    return unless auth_code

    auth_code.destroy
    user.auth_codes.delete_all
    user
  end
end
