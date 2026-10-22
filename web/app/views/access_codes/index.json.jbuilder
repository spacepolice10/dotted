# frozen_string_literal: true

json.array! @access_codes do |access_code|
  json.id access_code.id
  json.code_prefix access_code.code_prefix
  json.description access_code.description
  json.created_at access_code.created_at
end
