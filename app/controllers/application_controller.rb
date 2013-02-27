class ApplicationController < ActionController::Base
  protect_from_forgery

  include GDS::SSO::ControllerMethods

private
  def error_404
    error 404, "not found"
  end

  def error(code, message)
    @status = message
    render "base/error", :status => code, :handlers => :rabl, :formats => [:json]
  end

  def set_expiry(duration = 30.minutes)
    unless Rails.env.development?
      expires_in duration, :public => true, "stale-if-error" => 24.hours, "stale-while-revalidate" => 24.hours
    end
  end
end
