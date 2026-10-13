# frozen_string_literal: true

json.array! @attachments do |attachment|
  json.partial! 'attachments/attachment', locals: { blob: attachment.blob }
end
