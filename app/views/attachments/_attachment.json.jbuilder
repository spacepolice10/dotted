# frozen_string_literal: true

json.signed_id blob.signed_id
json.filename blob.filename.to_s
json.content_type blob.content_type
json.byte_size blob.byte_size
json.url attachment_url(blob.signed_id)
json.download_url rails_blob_url(blob, disposition: 'attachment')
