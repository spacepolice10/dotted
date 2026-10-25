# frozen_string_literal: true

module Collectable
  extend ActiveSupport::Concern

  def collect!(collection_id:)
    destination = user.collections.find(collection_id)
    return update!(reviewed_at: Time.current) if self.collection_id == destination.id

    transaction do
      collection_item&.destroy!
      update!(collection: destination, reviewed_at: Time.current)
    end
  end
end
