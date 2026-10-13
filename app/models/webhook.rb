# frozen_string_literal: true

# Inbound intake for external apps. Plaintext code is shown once at create.
# POSTs to /webhooks/:code land text bullets on the user's timeline.
class Webhook < ApplicationRecord
  PREFIX = 'wh_'
  CODE_BYTE = 24
  PREFIX_DISPLAY_LENGTH = 8

  belongs_to :user

  attr_accessor :code

  scope :active, -> { where(active: true) }

  validates :name, presence: true, length: { maximum: 255 }
  validates :code_digest, :code_prefix, presence: true
  validates :code_digest, uniqueness: true

  before_validation :generate_code, on: :create

  def self.digest(code)
    Digest::SHA256.hexdigest(code.to_s)
  end

  def self.authenticate(code)
    return if code.blank?

    active.find_by(code_digest: digest(code))
  end

  def create_bullet!(author_name:, body:)
    user.bullets.create!(
      author_name: author_name.to_s.strip.presence,
      body: body
    )
  end

  private

  def generate_code
    return if code_digest.present?

    self.code = "#{PREFIX}#{SecureRandom.base58(CODE_BYTE)}"
    self.code_digest = self.class.digest(code)
    self.code_prefix = code.first(PREFIX_DISPLAY_LENGTH)
  end
end
