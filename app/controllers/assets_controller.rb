class AssetsController < ApplicationController
  before_action :restrict_request_format

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

  def update
    @asset = Asset.undeleted.or(Asset.where(draft: true)).find(params[:id])

    if @asset.update(asset_params)
      render json: AssetPresenter.new(@asset, view_context).as_json(status: :success)
    else
      error 422, @asset.errors.full_messages
    end
  end

  def destroy
    @asset = find_asset
    @asset.destroy!
    render json: AssetPresenter.new(@asset, view_context).as_json(status: :success)
  end

  def restore
    @asset = find_asset(include_deleted: true)
    @asset.restore
    render json: AssetPresenter.new(@asset, view_context).as_json(status: :success)
  end

private

  def restrict_request_format
    request.format = :json
  end

  def asset_params
    params.require(:asset).tap { |asset|
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
    }.permit(
      :file,
      :draft,
      :redirect_url,
      :replacement_id,
      :parent_document_url,
      :content_type,
      access_limited: [],
      access_limited_organisation_ids: [],
      auth_bypass_ids: [],
    )
  end

  def find_asset(include_deleted: false)
    scope = include_deleted ? Asset : Asset.undeleted
    scope.find(params[:id])
  end

  def build_asset
    Asset.new(asset_params)
  end
end
