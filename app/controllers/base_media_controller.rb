class BaseMediaController < ApplicationController
  skip_before_action :require_signin_permission!

protected

  def proxy_percentage_of_asset_requests_to_s3_via_nginx
    raise NotImplementedError
  end

  def proxy_to_s3_via_nginx?
    random_number_generator = Random.new
    percentage = proxy_percentage_of_asset_requests_to_s3_via_nginx
    proxy_to_s3_via_nginx = random_number_generator.rand(100) < percentage
    proxy_to_s3_via_nginx || params[:proxy_to_s3_via_nginx].present?
  end

  def proxy_to_s3_via_nginx(asset)
    url = Services.cloud_storage.presigned_url_for(asset, http_method: request.request_method)
    headers['X-Accel-Redirect'] = "/cloud-storage-proxy/#{url}"
    headers['ETag'] = %{"#{asset.etag}"}
    headers['Last-Modified'] = asset.last_modified.httpdate
    headers['Content-Disposition'] = AssetManager.content_disposition.header_for(asset)
    head :ok, content_type: asset.content_type
  end

  def serve_from_nfs_via_nginx(asset)
    send_file(asset.file.path, disposition: AssetManager.content_disposition.type)
  end
end
