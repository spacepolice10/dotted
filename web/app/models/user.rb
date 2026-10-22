# frozen_string_literal: true

# Authenticated user and owner of all their bullets, collections, and settings.
class User < ApplicationRecord
  has_one :settings, class_name: 'User::Settings', dependent: :destroy
  after_create :create_settings

  has_many :sessions, dependent: :destroy
  has_many :auth_codes, dependent: :destroy
  has_many :access_codes, dependent: :destroy
  has_many :webhooks, dependent: :destroy
  has_many :bullets, dependent: :destroy
  has_many :activities, dependent: :destroy
  has_many :collections, dependent: :destroy
  has_many :published_entities, dependent: :destroy
  has_many :search_selections, class_name: 'Search::Selection', dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  def settings!
    settings || create_settings!
  end

  def name
    email_address.split('@').first
  end
end
