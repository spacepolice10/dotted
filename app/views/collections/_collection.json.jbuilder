# frozen_string_literal: true

json.extract! collection, :id, :name, :description, :colour, :icon, :created_at, :updated_at
json.url collection_url(collection)
