# frozen_string_literal: true

# Long-lived API credentials for CLI / integrations. Plaintext is shown once at create.
class AccessCode < ApplicationRecord
  PREFIX = 'dj_'
  CODE_BYTES = 24
  PREFIX_DISPLAY_LENGTH = 8

  belongs_to :user

  attr_accessor :code

  validates :code_digest, :code_prefix, presence: true
  validates :code_digest, uniqueness: true
  validates :description, length: { maximum: 255 }, allow_blank: true

  before_validation :generate_code, on: :create

  def self.digest(code)
    Digest::SHA256.hexdigest(code.to_s)
  end

  def self.authenticate(code)
    return if code.blank?

    find_by(code_digest: digest(code))
  end

  private

  def generate_code
    return if code_digest.present?

    self.code = "#{PREFIX}#{SecureRandom.base58(CODE_BYTES)}"
    self.code_digest = self.class.digest(code)
    self.code_prefix = code.first(PREFIX_DISPLAY_LENGTH)
  end
end
