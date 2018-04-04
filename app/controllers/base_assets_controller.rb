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

  def normalize_redirect_url(params)
    params.reject { |k, v| (k.to_sym == :redirect_url) && v.blank? }
  end

  def normalize_access_limited(params)
    if params.has_key?(:asset) && params[:asset].has_key?(:access_limited) && params[:asset][:access_limited].empty?
      params[:asset][:access_limited] = []
    end
    params
  end
end
