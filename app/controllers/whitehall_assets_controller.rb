class WhitehallAssetsController < ApplicationController
  def create
    @asset = WhitehallAsset.new(asset_params)

    if @asset.save
      render json: AssetPresenter.new(@asset, view_context).as_json(status: :created), status: :created
    else
      error 422, @asset.errors.full_messages
    end
  end

private

  def asset_params
    params.require(:asset).permit(:file, :legacy_url_path, :legacy_etag)
  end
end
