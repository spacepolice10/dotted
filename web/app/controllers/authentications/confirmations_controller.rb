# frozen_string_literal: true

module Authentications
  class ConfirmationsController < ApplicationController
    allow_unauthenticated_access
    rate_limit to: 5, within: 3.minutes, only: :create, with: lambda {
      respond_to do |format|
        format.html { redirect_to new_authentication_confirmation_path, alert: 'Try again later.' }
        format.json { head :too_many_requests }
      end
    }

    def new
      @email = session[:login_email]
      redirect_to new_authentication_path unless @email
    end

    def create
      json_request? ? confirm_browserless : confirm_browser
    end

    private

    def confirm_browser
      user = consume_auth_code(session[:login_email])

      if user
        create_confirmed_session_of(user)
        redirect_to stashed_authentication_path
      else
        redirect_to new_authentication_confirmation_path, alert: 'Invalid or expired code.'
      end
    end

    def confirm_browserless
      code = pending_authentication_code_from_request
      return if code.blank?

      verified_code = pending_authentication_verifier.verified(code)
      user = consume_auth_code(verified_code)

      if user
        create_confirmed_session_of(user)
        @session_code = create_session_code(Current.session)
        render :create
      else
        head :unauthorized
      end
    end

    def consume_auth_code(email)
      return if email.blank?

      AuthCode.consume!(email: email, code: params[:code])
    end

    def create_confirmed_session_of(user)
      session.delete(:login_email)
      remove_pending
      create_session_of(user)
    end
  end
end
