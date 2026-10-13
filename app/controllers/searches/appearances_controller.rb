# frozen_string_literal: true

module Searches
  # Persists the user's background appearance tint.
  class AppearancesController < ApplicationController
    def update
      appearance = params[:appearance]
      return head :unprocessable_entity unless User::Settings::APPEARANCES.include?(appearance)

      Current.user.settings!.update!(appearance: appearance)
      head :ok
    end
  end
end
