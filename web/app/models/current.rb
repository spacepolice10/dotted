# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :session, :access_code

  def user
    access_code&.user || session&.user
  end
end
