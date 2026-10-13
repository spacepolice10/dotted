# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require_relative 'test_helpers/dom_assertions'
require_relative 'test_helpers/session_test_helper'

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def create_blob!(filename:, content_type: 'application/pdf')
      ActiveStorage::Blob.create_and_upload!(io: StringIO.new('x'), filename: filename, content_type: content_type)
    end

    def create_file_bullet!(user, filename: 'pixel.png', content_type: 'image/png', io: StringIO.new('x'), **attrs)
      user.bullets.new(attrs).tap do |bullet|
        bullet.file.attach(io: io, filename: filename, content_type: content_type)
        bullet.save!
      end
    end

    def create_collection!(user, name:, colour: nil, icon: nil)
      user.collections.create!(name: name, colour: colour, icon: icon)
    end

    def create_bullet!(user, **attrs)
      if (collection = attrs.delete(:collection))
        attrs[:collection_id] = collection.id
      end
      user.bullets.create!(attrs)
    end
  end
end
