# frozen_string_literal: true

Rails.application.config.to_prepare do
  ActionText::ContentHelper.allowed_attributes = ActionText::ContentHelper.sanitizer.class.allowed_attributes +
    ActionText::Attachment::ATTRIBUTES + %w[target rel]
end
