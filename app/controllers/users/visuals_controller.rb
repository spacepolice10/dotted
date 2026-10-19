# frozen_string_literal: true

module Users
  class VisualsController < ApplicationController
    def show; end

    def update
      settings = Current.user.settings!
      if settings.update(appearance: params[:appearance])
        redirect_to user_visuals_path, status: :see_other
      else
        @appearance_error = 'Choose an available theme.'
        settings.reload
        render :show, status: :unprocessable_entity
      end
    end
  end
end
