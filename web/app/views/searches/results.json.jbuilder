# frozen_string_literal: true

json.array! @entries do |entry|
  json.id entry.id
  json.type entry.class.name
  json.name entry.name
  json.url polymorphic_url(entry)
end
