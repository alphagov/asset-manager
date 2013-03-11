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
end
