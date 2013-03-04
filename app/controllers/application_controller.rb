class ApplicationController < ActionController::Base
  protect_from_forgery

  include GDS::SSO::ControllerMethods

  before_filter :authenticate_user!
  before_filter :require_signin_permission!

  rescue_from Mongoid::Errors::DocumentNotFound, :with => :error_404
  rescue_from BSON::InvalidObjectId, :with => :error_404

private
  def error_404
    error 404, "not found"
  end

  def error(code, message)
    render :json => {:_response_info => {:status => message}}, :status => code
  end

  def set_expiry(duration = 30.minutes)
    unless Rails.env.development?
      expires_in duration, :public => true, "stale-if-error" => 24.hours, "stale-while-revalidate" => 24.hours
    end
  end
end
