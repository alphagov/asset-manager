class WhitehallAssetsController < ApplicationController
  def create
    @asset = WhitehallAsset.new(asset_params)

    if @asset.save
      presenter = AssetPresenter.new(@asset, view_context)
      render json: presenter.as_json(status: :created), status: :created
    else
      error 422, @asset.errors.full_messages
    end
  end

private

  def asset_params
    params
      .require(:asset)
      .permit(:file, :legacy_url_path, :legacy_etag, :legacy_last_modified)
  end
end
