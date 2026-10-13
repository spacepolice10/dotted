# frozen_string_literal: true

json.id @webhook.id
json.name @webhook.name
json.code @webhook.code
json.url webhook_intake_url(@webhook.code)
json.created_at @webhook.created_at
