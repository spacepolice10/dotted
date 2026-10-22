# frozen_string_literal: true

class WebhooksController < ApplicationController
  def index
    @webhooks = Current.user.webhooks.order(created_at: :desc)
    @created_webhook_code = flash[:webhook_code]

    respond_to do |format|
      format.html
      format.json
    end
  end

  def new
    @webhook = Current.user.webhooks.new
  end

  def create
    @webhook = Current.user.webhooks.new(webhook_params)

    if @webhook.save
      respond_to do |format|
        format.html do
          flash[:webhook_code] = @webhook.code
          redirect_to webhooks_path
        end
        format.json { render :create, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @webhook.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @webhook = Current.user.webhooks.find(params[:id])
    @webhook.destroy!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to webhooks_path, status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  def webhook_params
    params.require(:webhook).permit(:name)
  end
end
