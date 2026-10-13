# frozen_string_literal: true

class BulletsController < ApplicationController
  include FilterScoped

  before_action :set_bullet, only: %i[show update destroy]
  before_action :set_filter, only: :index
  before_action :set_timeline, only: :index
  def index
    if params[:before].present?
      load_prev_page
    else
      @bullets = @timeline.last_page
      @more_bullets = @bullets.size == Bullet::Pageable::PAGE_SIZE
    end
  end

  def create
    return created_response if find_existing_by_client_id

    @bullet = Current.user.bullets.new(bullet_params)

    if @bullet.save
      created_response
    else
      failed_create_response
    end
  rescue ActiveRecord::RecordNotUnique
    raise unless find_existing_by_client_id

    created_response
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    @bullet = Current.user.bullets.new
    @bullet.errors.add(:file, 'is invalid')
    failed_create_response
  end

  def show
    return render :show, formats: :json if request.format.json?

    @timeline = Timeline.new(Current.user)
    @bullets = @timeline.on(@bullet.pops_on).to_a
    # A completed or not-yet-due bullet has no active siblings on its day, and
    # an empty rail would leave the page with nothing to look at.
    @bullets = [@bullet] if @bullets.empty?
  end

  def update
    if @bullet.update(bullet_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bullet_path(@bullet) }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.turbo_stream { notify_failure }
        format.html { redirect_to bullet_path(@bullet), alert: bullet_errors.to_sentence, status: :see_other }
        format.json { render json: bullet_errors_by_attribute, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @bullet.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to bullets_path }
      format.json { head :no_content }
    end
  end

  private

  def load_prev_page
    cursor = @timeline.filtered.find_by(id: params[:before])
    return head :no_content unless cursor

    @bullets = @timeline.prev_page(cursor)
    return head :no_content if @bullets.empty?

    respond_to do |format|
      format.html { render :load_prev_page, layout: false }
      format.json { render 'bullets/index', formats: :json, if: stale?(etag: @bullets) }
    end
  end

  def find_existing_by_client_id
    client_id = params.dig(:bullet, :client_id).presence
    return false unless client_id

    @bullet = Current.user.bullets.find_by(client_id: client_id)
  end

  def created_response
    respond_to do |format|
      format.json do
        response.set_header('Location', bullet_url(@bullet))
        render :create, status: :created
      end
      format.turbo_stream { render :create }
      format.html { redirect_to bullet_path(@bullet), status: :see_other }
    end
  end

  def failed_create_response
    respond_to do |format|
      format.json { render json: bullet_errors_by_attribute, status: :unprocessable_entity }
      format.turbo_stream { notify_failure }
      format.html do
        redirect_to bullets_path, alert: bullet_errors.to_sentence, status: :see_other
      end
    end
  end

  def set_bullet
    @bullet = Current.user.bullets.find(params[:id])
  end

  def bullet_params
    if @bullet&.persisted?
      params.require(:bullet).permit(:body, :file)
    else
      params.require(:bullet).permit(:pops_on, :collection_id, :body, :file, :client_id)
    end
  end

  def notify_failure(messages = bullet_errors)
    render turbo_stream: turbo_stream.update(
      'toasts',
      partial: 'shared/toasts',
      locals: { type: 'errmsg', messages: Array(messages) }
    ), status: :unprocessable_entity
  end

  def bullet_errors
    @bullet.errors.map(&:full_message).uniq.presence || ['Bullet could not be saved']
  end

  def bullet_errors_by_attribute
    errors = {}
    @bullet.errors.each do |error|
      (errors[error.attribute] ||= []) << error.message
    end
    errors.presence || { base: ['Bullet could not be saved'] }
  end
end
