# frozen_string_literal: true

json.array! @webhooks do |webhook|
  json.id webhook.id
  json.name webhook.name
  json.code_prefix webhook.code_prefix
  json.active webhook.active
  json.created_at webhook.created_at
end
