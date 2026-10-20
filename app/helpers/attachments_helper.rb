# frozen_string_literal: true

# File-format hints for attachment presentation; uploaded bytes remain unchanged.
module AttachmentsHelper
  # MIME types take precedence; dotted extensions cover generic upload MIME types.
  FILE_ICONS = {
    'application/epub+zip' => 'book-2',
    '.epub' => 'book-2'
  }.freeze

  def attachment_icon(file)
    FILE_ICONS[file&.content_type] ||
      FILE_ICONS[".#{file&.filename&.extension.to_s.downcase}"] ||
      'file'
  end
end
