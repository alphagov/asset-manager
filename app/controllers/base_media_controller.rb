class BaseMediaController < ApplicationController
  skip_before_action :require_signin_permission!

protected

  def proxy_to_s3_via_nginx(asset)
    url = Services.cloud_storage.presigned_url_for(asset, http_method: request.request_method)
    headers['X-Accel-Redirect'] = "/cloud-storage-proxy/#{url}"
    headers['ETag'] = %{"#{asset.etag}"}
    headers['Last-Modified'] = asset.last_modified.httpdate
    headers['Content-Disposition'] = AssetManager.content_disposition.header_for(asset)
    head :ok, content_type: asset.content_type
  end
end
