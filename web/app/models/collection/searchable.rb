# frozen_string_literal: true

module Collection::Searchable
  extend ActiveSupport::Concern
  include ::Searchable

  def searchable?
    true
  end

  def search_name
    name
  end

  def search_body
    [name, description].compact.join(' ')
  end

  def search_result_body
    [name, description].compact_blank.join(' — ')
  end

  def search_result_icon = 'hash'

  def search_result_type = self.class.name.titleize
end
