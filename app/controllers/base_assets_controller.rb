class BaseAssetsController < ApplicationController
  def show
    @asset = find_asset

    @asset.unscanned? ? set_expiry(0) : set_expiry(30.minutes)
    render json: AssetPresenter.new(@asset, view_context)
  end
end
