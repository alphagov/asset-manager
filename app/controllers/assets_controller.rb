class AssetsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :require_signin_permission!
  before_filter :restrict_request_format

  def show
    @asset = Asset.find(params[:id])

    render :json => @asset.decorate
  end

  def create
    @asset = Asset.new(params[:asset])

    if @asset.save
      render :json => @asset.decorate.as_json(:status => :created), :status => :created
    else
      error 422, @asset.errors.full_messages
    end
  end

private
  def restrict_request_format
    request.format = :json
  end
end
