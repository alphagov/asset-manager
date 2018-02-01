class AssetsController < ApplicationController
  before_action :restrict_request_format

  def show
    @asset = Asset.find(params[:id])

    @asset.unscanned? ? set_expiry(0) : set_expiry(30.minutes)
    render json: AssetPresenter.new(@asset, view_context)
  end

  def create
    @asset = Asset.new(asset_params)

    if @asset.save
      render json: AssetPresenter.new(@asset, view_context).as_json(status: :created), status: :created
    else
      error 422, @asset.errors.full_messages
    end
  end

  def update
    @asset = Asset.find(params[:id])

    if @asset.update_attributes(asset_params)
      render json: AssetPresenter.new(@asset, view_context).as_json(status: :success)
    else
      error 422, @asset.errors.full_messages
    end
  end

  def destroy
    @asset = Asset.find(params[:id])

    if @asset.destroy
      render json: AssetPresenter.new(@asset, view_context).as_json(status: :success)
    else
      error 422, @asset.errors.full_messages
    end
  end

  def restore
    @asset = Asset.unscoped.find(params[:id])

    if @asset.restore
      render json: AssetPresenter.new(@asset, view_context).as_json(status: :success)
    else
      error 422, @asset.errors.full_messages
    end
  end

private

  def restrict_request_format
    request.format = :json
  end

  def asset_params
    params.require(:asset).permit(:file, :draft)
  end
end
