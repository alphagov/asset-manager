class WhitehallAssetClonerController < BaseAssetsController
  def clone_whitehall_asset_to_asset
    @asset = build_asset

    if @asset.save
      render json: AssetPresenter.new(@asset, view_context).as_json(status: :created), status: :created
    else
      error 422, @asset.errors.full_messages
    end
  end

private

  def restrict_request_format
    request.format = :json
  end

  def whitehall_asset_params
    whitehall_asset = WhitehallAsset.find_by(legacy_url_path: params[:legacy_url_path])
    {
      file: whitehall_asset.file,
      draft: whitehall_asset.draft,
      state: whitehall_asset.state,
      redirect_url: whitehall_asset.redirect_url,
      parent_document_url: whitehall_asset.parent_document_url,
      created_at: whitehall_asset.created_at,
      updated_at: whitehall_asset.updated_at,
      access_limited: whitehall_asset.access_limited,
      access_limited_organisation_ids: whitehall_asset.access_limited_organisation_ids,
      auth_bypass_ids: whitehall_asset.auth_bypass_ids,
    }
  end

  def build_asset
    Asset.new(whitehall_asset_params)
  end
end
