# frozen_string_literal: true

blob = bullet.file.blob
json.bullet_id bullet.id
json.filename blob.filename.to_s
json.content_type blob.content_type
json.byte_size blob.byte_size
json.url attachment_url(bullet)
json.download_url rails_blob_url(blob, disposition: 'attachment')
