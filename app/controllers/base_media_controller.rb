class BaseMediaController < ApplicationController
  skip_before_action :authenticate_user!, unless: :requested_from_draft_assets_host?

protected

  def requested_from_draft_assets_host?
    request.host == AssetManager.govuk.draft_assets_host
  end

  def proxy_to_s3_via_nginx(asset)
    headers['ETag'] = %{"#{asset.etag}"}
    headers['Last-Modified'] = asset.last_modified.httpdate
    headers['Content-Disposition'] = AssetManager.content_disposition.header_for(asset)

    unless request.fresh?(response)
      url = Services.cloud_storage.presigned_url_for(asset, http_method: request.request_method)
      headers['X-Accel-Redirect'] = "/cloud-storage-proxy/#{url}"
    end

    head :ok, content_type: asset.content_type
  end
end
