# frozen_string_literal: true

json.array! @collections do |collection|
  json.partial! 'collections/collection', locals: { collection: collection }
end
