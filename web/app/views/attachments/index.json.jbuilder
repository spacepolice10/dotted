# frozen_string_literal: true

json.array! @bullets do |bullet|
  json.partial! 'attachments/attachment', locals: { bullet: bullet }
end
