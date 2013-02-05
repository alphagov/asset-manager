class ApplicationController < ActionController::Base
  protect_from_forgery

  private
    def error_404
      render "base/not_found", :status => 404
    end
end
