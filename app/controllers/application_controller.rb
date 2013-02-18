class ApplicationController < ActionController::Base
  protect_from_forgery

  include GDS::SSO::ControllerMethods

  before_filter :authenticate_user!
  before_filter :require_signin_permission!

private
  def error_404
    error 404, "not found"
  end

  def error(code, message)
    @status = message
    render "base/error", :status => code
  end
end
