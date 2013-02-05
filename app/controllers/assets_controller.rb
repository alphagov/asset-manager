class AssetsController < ApplicationController
  before_filter :restrict_request_format

  def create
    @asset = Asset.new(params[:asset])

    if @asset.save
      render "create", :status => :created
    else
      render :json => { :errors => @asset.errors.full_messages }, :status => :unprocessable_entity
    end
  end

  private
    def restrict_request_format
      request.format = :json
    end
end
