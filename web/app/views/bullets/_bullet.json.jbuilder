# frozen_string_literal: true

json.id bullet.id
json.pops_on bullet.pops_on
json.collection_id bullet.collection_id
json.done bullet.done?
json.author_name bullet.author_name
json.filename bullet.filename
json.body bullet.body_as_text
json.body_html bullet.body.to_s
json.created_at bullet.created_at
json.updated_at bullet.updated_at
json.url bullet_url(bullet)
json.public_url published_url(bullet.public_code) if bullet.published?

if bullet.file.attached?
  json.content_type bullet.file.content_type
  json.byte_size bullet.file.byte_size
end
