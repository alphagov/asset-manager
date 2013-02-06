class ApplicationController < ActionController::Base
  protect_from_forgery

  private
    def error_404
      error 404, "not found"
    end

    def error(code, message)
      @status = message
      render "base/error", :status => code
    end
end
