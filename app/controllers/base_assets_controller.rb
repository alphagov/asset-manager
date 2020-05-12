class BaseAssetsController < ApplicationController
  def show
    @asset = find_asset(include_deleted: true)

    expires_now
    render json: AssetPresenter.new(@asset, view_context)
  end

  def create
    @asset = build_asset

    if @asset.save
      render json: AssetPresenter.new(@asset, view_context).as_json(status: :created), status: :created
    else
      error 422, @asset.errors.full_messages
    end
  end

protected

  def base_asset_params
    params.require(:asset).tap do |asset|
      if asset.key?(:redirect_url) && asset[:redirect_url].blank?
        asset[:redirect_url] = nil
      end

      if asset.key?(:access_limited_user_ids)
        asset[:access_limited] = asset[:access_limited_user_ids]
      end

      if asset.key?(:access_limited) && asset[:access_limited].empty?
        asset[:access_limited] = []
      end

      if asset.key?(:access_limited_organisation_ids) && asset[:access_limited_organisation_ids].empty?
        asset[:access_limited_organisation_ids] = []
      end

      if asset.key?(:auth_bypass_ids) && asset[:auth_bypass_ids].empty?
        asset[:auth_bypass_ids] = []
      end
    end
  end
end
