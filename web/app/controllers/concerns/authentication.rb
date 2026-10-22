# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  PENDING_AUTHENTICATION_COOKIE = :pending_authentication_code
  SESSION_CODE_EXPIRY = 15.minutes

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def authenticated?
    resume_session || with_access_code?
  end

  def require_authentication
    resume_session || authenticate_by_access_code || request_authentication
  end

  def resume_session
    Current.session ||= find_session
  end

  def with_access_code?
    Current.access_code.present?
  end

  def find_session
    find_session_by_cookie || find_session_by_bearer_session_code
  end

  def find_session_by_cookie
    Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
  end

  # Bearer is tried as AccessCode first in authenticate_by_access_code; only
  # session verifier codes belong here (and only when no AccessCode matched).
  # Lets a CLI mint an AccessCode after magic-link confirm without a cookie jar.
  def find_session_by_bearer_session_code
    return if access_code_from_bearer

    find_session_by_code(bearer_credentials)
  end

  def find_session_by_code(code)
    return if code.blank?

    session_id = session_code_verifier.verified(code)
    Session.find_by(id: session_id) if session_id
  end

  def authenticate_by_access_code
    return unless json_request?

    access_code = access_code_from_bearer
    return unless access_code

    Current.access_code = access_code
    true
  end

  def access_code_from_bearer
    return @access_code_from_bearer if defined?(@access_code_from_bearer)

    @access_code_from_bearer = AccessCode.authenticate(bearer_credentials)
  end

  def bearer_credentials
    request.authorization&.match(/\ABearer (.+)\z/i)&.captures&.first
  end

  def request_authentication
    respond_to do |format|
      format.html do
        session[:stashed_authentication_path] = request.fullpath
        redirect_to new_authentication_path
      end
      format.json { render json: { error: 'Unauthorized' }, status: :unauthorized }
    end
  end

  # Path the user was trying to open before login; cleared after one use.
  def stashed_authentication_path
    path = session.delete(:stashed_authentication_path).presence
    return path if path&.start_with?('/') && !path.start_with?('//')

    root_path
  end

  def create_session_of(user)
    user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
      Current.session = session
      cookies.signed.permanent[:session_id] = { value: session.id, **auth_cookie_options }
    end
  end

  def terminate_session
    Current.session&.destroy
    cookies.delete(:session_id)
  end

  def create_pending_authentication_code(email)
    pending_authentication_verifier.generate(email, expires_in: AuthCode::EXPIRY)
  end

  def create_session_code(session)
    session_code_verifier.generate(session.id, expires_in: SESSION_CODE_EXPIRY)
  end

  def create_pending_authentication_cookie(code)
    cookies[PENDING_AUTHENTICATION_COOKIE] = {
      value: code,
      expires: AuthCode::EXPIRY.from_now,
      **auth_cookie_options
    }
  end

  def auth_cookie_options
    { httponly: true, same_site: :lax, secure: Rails.env.production? }
  end

  def remove_pending
    cookies.delete(PENDING_AUTHENTICATION_COOKIE)
  end

  def pending_authentication_code_from_request
    params[:pending_authentication_code].presence || cookies[PENDING_AUTHENTICATION_COOKIE]
  end

  def json_request?
    request.format.json?
  end

  def pending_authentication_verifier
    Rails.application.message_verifier(:pending_authentication)
  end

  def session_code_verifier
    Rails.application.message_verifier(:session_code)
  end
end
