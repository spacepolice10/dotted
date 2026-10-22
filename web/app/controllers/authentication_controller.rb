# frozen_string_literal: true

class AuthenticationController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 5, within: 2.minutes, only: :create, with: lambda {
    respond_to do |format|
      format.html { redirect_to new_authentication_path, alert: 'Try again in a few minutes.' }
      format.json { head :too_many_requests }
    end
  }

  def new
    @user = User.new
  end

  def create
    email = User.normalize_value_for(:email_address, authentication_params[:email_address])
    @user = User.find_or_initialize_by(email_address: email)
    if @user.save
      _record, code = AuthCode.create_for(@user)
      SessionMailer.login_code(@user, code).deliver_later
      session[:login_email] = @user.email_address
      @pending_authentication_code = create_pending_authentication_code(@user.email_address)
      create_pending_authentication_cookie(@pending_authentication_code)

      respond_to do |format|
        format.html { redirect_to new_authentication_confirmation_path }
        format.json { render :create, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    terminate_session
    respond_to do |format|
      format.html { redirect_to new_authentication_path, status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  def authentication_params
    params.permit(:email_address)
  end
end
