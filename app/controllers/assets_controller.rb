class AssetsController < BaseAssetsController
  before_action :restrict_request_format

  def update
    @asset = find_asset

    if @asset.update_attributes(asset_params)
      render json: AssetPresenter.new(@asset, view_context).as_json(status: :success)
    else
      error 422, @asset.errors.full_messages
    end
  end

  def destroy
    @asset = find_asset

    if @asset.destroy
      render json: AssetPresenter.new(@asset, view_context).as_json(status: :success)
    else
      error 422, @asset.errors.full_messages
    end
  end

  def restore
    @asset = find_asset(include_deleted: true)

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
    normalize_redirect_url(
      handle_empty_access_limited_param(params)
        .require(:asset)
        .permit(:file, :draft, :redirect_url, :replacement_id, :parent_document_url, access_limited: [])
    )
  end

  def find_asset(include_deleted: false)
    scope = include_deleted ? Asset.unscoped : Asset
    scope.find(params[:id])
  end

  def build_asset
    Asset.new(asset_params)
  end
end
