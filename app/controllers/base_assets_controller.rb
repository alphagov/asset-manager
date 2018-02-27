class BaseAssetsController < ApplicationController
  def show
    @asset = find_asset

    set_expiry(cache_control.expires_in(0.minutes))
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

  def exclude_blank_redirect_url(params)
    params.reject { |k, v| (k.to_sym == :redirect_url) && v.blank? }
  end

  def cache_control
    AssetManager.cache_control
  end
end
