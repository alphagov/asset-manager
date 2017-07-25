require 'cloud_storage'

class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session

  include GDS::SSO::ControllerMethods

  before_filter :require_signin_permission!

  rescue_from Mongoid::Errors::DocumentNotFound, with: :error_404
  rescue_from CloudStorage::NotConfiguredError, with: :error_500

private

  def error_404
    error 404, "not found"
  end

  def error_500(e)
    error 500, "Internal server error: #{e.message}"
  end

  def error(code, message)
    render json: { _response_info: { status: message } }, status: code
  end

  def set_expiry(duration)
    expires_in duration, public: true unless Rails.env.development?
  end
end
