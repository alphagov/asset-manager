class MediaController < BaseMediaController
  before_filter :authenticate_if_private

  def download
    unless asset_servable?
      error_404
      return
    end

    unless filename_current?
      redirect_to_current_filename
      return
    end

    respond_to do |format|
      format.any do
        set_expiry(AssetManager.cache_control.max_age)
        headers['X-Frame-Options'] = AssetManager.frame_options
        if proxy_to_s3_via_nginx?
          proxy_to_s3_via_nginx(asset)
        else
          serve_from_nfs_via_nginx(asset)
        end
      end
    end
  end

protected

  def proxy_percentage_of_asset_requests_to_s3_via_nginx
    AssetManager.proxy_percentage_of_asset_requests_to_s3_via_nginx
  end

  def filename_current?
    asset.filename == params[:filename]
  end

  def asset_servable?
    asset.filename_valid?(params[:filename]) &&
      asset.clean? &&
      asset.accessible_by?(current_user) &&
      asset.mainstream?
  end

  def authenticate_if_private
    require_signin_permission! if requested_via_private_vhost?
  end

  def asset
    @asset ||= Asset.find(params[:id])
  end

  def requested_via_private_vhost?
    request.host == ENV['PRIVATE_ASSET_MANAGER_HOST']
  end

  def redirect_to_current_filename
    redirect_to(
      action: :download,
      id: params[:id],
      filename: asset.filename,
      only_path: true,
    )
  end
end
