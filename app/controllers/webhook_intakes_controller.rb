# frozen_string_literal: true

# Unauthenticated intake: external apps POST JSON to create a timeline bullet.
class WebhookIntakesController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  rate_limit to: 60, within: 1.minute, only: :create, with: -> { head :too_many_requests }

  def create
    webhook = Webhook.authenticate(params[:code])
    return head :not_found unless webhook

    @bullet = webhook.create_bullet!(
      author_name: intake_params[:author_name],
      body: intake_params[:body]
    )

    response.set_header('Location', bullet_url(@bullet))
    render template: 'bullets/create', status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: e.record.errors, status: :unprocessable_entity
  end

  private

  def intake_params
    params.permit(:author_name, :body)
  end
end
