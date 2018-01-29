class WhitehallAssetsController < ApplicationController
  def create
    if existing_asset_with_this_legacy_url_path.exists?
      existing_asset_with_this_legacy_url_path.destroy
    end

    @asset = WhitehallAsset.new(asset_params)

    if @asset.save
      presenter = AssetPresenter.new(@asset, view_context)
      render json: presenter.as_json(status: :created), status: :created
    else
      error 422, @asset.errors.full_messages
    end
  end

  def show
    path = "/#{params[:path]}.#{params[:format]}"
    @asset = WhitehallAsset.find_by(legacy_url_path: path)

    @asset.unscanned? ? set_expiry(0) : set_expiry(30.minutes)
    render json: AssetPresenter.new(@asset, view_context)
  end

private

  def asset_params
    params
      .require(:asset)
      .permit(:file, :draft, :legacy_url_path, :legacy_etag, :legacy_last_modified)
  end

  def existing_asset_with_this_legacy_url_path
    WhitehallAsset.where(legacy_url_path: asset_params[:legacy_url_path])
  end
end
