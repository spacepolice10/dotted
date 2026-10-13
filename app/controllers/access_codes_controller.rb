# frozen_string_literal: true

# Creates and revokes API credentials for the signed-in user.
class AccessCodesController < ApplicationController
  def index
    @access_codes = Current.user.access_codes.order(created_at: :desc)
    @created_access_code = flash[:access_code]
    response.headers['Cache-Control'] = 'no-store' if @created_access_code.present?

    respond_to do |format|
      format.html
      format.json
    end
  end

  def new
    @access_code = Current.user.access_codes.new
  end

  def create
    @access_code = Current.user.access_codes.new(access_code_params)

    if @access_code.save
      respond_to_created_access_code
    else
      respond_to_invalid_access_code
    end
  end

  def destroy
    @access_code = Current.user.access_codes.find(params[:id])
    @access_code.destroy!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to access_codes_path, status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  def respond_to_created_access_code
    respond_to do |format|
      format.html do
        flash[:access_code] = @access_code.code
        redirect_to access_codes_path
      end
      format.json { render :create, status: :created }
    end
  end

  def respond_to_invalid_access_code
    respond_to do |format|
      format.html { render :new, status: :unprocessable_entity }
      format.json { render json: @access_code.errors, status: :unprocessable_entity }
    end
  end

  def access_code_params
    params.require(:access_code).permit(:description)
  end
end
