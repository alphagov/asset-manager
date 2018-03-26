class TimeoutController < ApplicationController
  def show
    timeout = params[:sleep].to_i || 0
    sleep timeout
    render plain: "Slept for #{timeout} seconds"
  end
end
