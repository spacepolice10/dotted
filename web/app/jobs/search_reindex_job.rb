# frozen_string_literal: true

class SearchReindexJob < ApplicationJob
  def self.searchable_models
    Searchable.searchable_models
  end

  def perform
    self.class.searchable_models.each do |model|
      model.find_each(&:reindex)
    end
  end
end
