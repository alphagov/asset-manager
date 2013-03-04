class AssetsController < ApplicationController
  before_filter :restrict_request_format

  def show
    @asset = Asset.find(params[:id])

    render :json => AssetPresenter.new(@asset, view_context)
  end

  def create
    @asset = Asset.new(params[:asset])

    if @asset.save
      render :json => AssetPresenter.new(@asset, view_context).as_json(:status => :created), :status => :created
    else
      error 422, @asset.errors.full_messages
    end
  end

private
  def restrict_request_format
    request.format = :json
  end
end
