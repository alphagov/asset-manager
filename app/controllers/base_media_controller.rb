class BaseMediaController < ApplicationController
  skip_before_action :require_signin_permission!

protected

  def proxy_to_s3_via_nginx(asset)
    headers['ETag'] = %{"#{asset.etag}"}
    headers['Last-Modified'] = asset.last_modified.httpdate
    headers['Content-Disposition'] = AssetManager.content_disposition.header_for(asset)

    last_modified_from_request = request.headers['If-Modified-Since']
    etag_from_request = request.headers['If-None-Match']

    request_is_fresh = false
    if last_modified_from_request || etag_from_request
      request_is_fresh = true
      request_is_fresh &&= (Time.parse(last_modified_from_request) >= Time.parse(headers['Last-Modified'])) if last_modified_from_request
      request_is_fresh &&= (etag_from_request == headers['ETag']) if etag_from_request
    end

    unless request_is_fresh
      url = Services.cloud_storage.presigned_url_for(asset, http_method: request.request_method)
      headers['X-Accel-Redirect'] = "/cloud-storage-proxy/#{url}"
    end

    head :ok, content_type: asset.content_type
  end
end
