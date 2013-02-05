class AssetsController < ApplicationController
  before_filter :restrict_request_format

  rescue_from Mongoid::Errors::DocumentNotFound, :with => :error_404
  rescue_from BSON::InvalidObjectId, :with => :error_404

  def show
    @asset = Asset.find(params[:id])
  end

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
