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
        if redirect_to_s3?
          set_expiry(AssetManager.cache_control.max_age)
          redirect_to Services.cloud_storage.public_url_for(asset)
        elsif proxy_to_s3_via_nginx?
          url = Services.cloud_storage.presigned_url_for(asset)
          headers['X-Accel-Redirect'] = "/cloud-storage-proxy/#{url}"
          headers['X-Accel-ETag'] = %{"#{asset.etag}"}
          headers['X-Accel-Last-Modified'] = asset.last_modified.httpdate
          render nothing: true
        elsif proxy_to_s3_via_rails?
          set_expiry(AssetManager.cache_control.max_age)
          body = Services.cloud_storage.load(asset)
          send_data(body.read, **AssetManager.content_disposition.options_for(asset))
        else
          set_expiry(AssetManager.cache_control.max_age)
          send_file(asset.file.path, disposition: AssetManager.content_disposition.type)
        end
      end
    end
  end

protected

  def redirect_to_s3?
    AssetManager.redirect_all_asset_requests_to_s3 || params[:redirect_to_s3].present?
  end

  def proxy_to_s3_via_nginx?
    random_number_generator = Random.new
    percentage = AssetManager.proxy_percentage_of_asset_requests_to_s3_via_nginx
    proxy_to_s3_via_nginx = random_number_generator.rand(100) < percentage
    proxy_to_s3_via_nginx || params[:proxy_to_s3_via_nginx].present?
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
