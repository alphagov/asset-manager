class MediaController < ApplicationController
  skip_before_filter :require_signin_permission!
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
        if redirect_to_s3?
          redirect_to Services.cloud_storage.public_url_for(asset)
        elsif proxy_to_s3_via_rails?
          body = Services.cloud_storage.load(asset)
          send_data(body.read, **AssetManager.content_disposition.options_for(asset))
        elsif proxy_to_s3_via_nginx?
          url = Services.cloud_storage.presigned_url_for(asset)
          headers['X-Accel-Redirect'] = "/cloud-storage-proxy/#{url}"
          render nothing: true
        else
          send_file(asset.file.path, disposition: AssetManager.content_disposition.type)
        end
      end
    end
  end

protected

  def proxy_to_s3_via_nginx?
    params[:proxy_to_s3_via_nginx].present?
  end

  def redirect_to_s3?
    AssetManager.redirect_all_asset_requests_to_s3 || params[:redirect_to_s3].present?
  end

  def proxy_to_s3_via_rails?
    AssetManager.proxy_all_asset_requests_to_s3_via_rails || params[:proxy_to_s3_via_rails].present?
  end

  def filename_current?
    asset.filename == params[:filename]
  end

  def asset_servable?
    asset.filename_valid?(params[:filename]) &&
      asset.clean? &&
      asset.accessible_by?(current_user)
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
