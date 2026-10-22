# frozen_string_literal: true

module Collectable
  extend ActiveSupport::Concern

  def collect!(collection_id:)
    destination = user.collections.find(collection_id)
    return if self.collection_id == destination.id

    update!(collection: destination)
  end
end
