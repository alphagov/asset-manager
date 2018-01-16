class HealthcheckController < ApplicationController
  skip_before_action :authenticate_user!

  def check
    render json: healthcheck.details.merge(status: healthcheck.status)
  end

private

  def healthcheck
    @healthcheck ||= Healthcheck.build
  end
end
