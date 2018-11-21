class MediaController < ApplicationController
  skip_before_action :authenticate_user!
  before_action { warden.authenticate }

  def download
    if redirect_to_draft_assets_host_for?(asset)
      redirect_to_draft_assets_host
      return
    end

    if requested_from_draft_assets_host? && !is_authenticated_for_asset?(asset)
      authenticate_user!
      return
    end

    unless asset.accessible_by?(current_user)
      head :forbidden
      return
    end

    unless asset_servable?
      error_404
      return
    end

    unless filename_current?
      redirect_to_current_filename
      return
    end

    if asset.redirect_url.present?
      redirect_to asset.redirect_url
      return
    end

    if asset.replacement.present? && (!asset.replacement.draft? || requested_from_draft_assets_host?)
      set_default_expiry
      redirect_to_replacement_for(asset)
      return
    end

    if temporary_redirect?
      perform_temporary_redirect
      return
    end

    if requested_from_draft_assets_host?
      expires_now
    else
      set_default_expiry
    end
    add_link_header(asset)
    add_frame_header
    proxy_to_s3_via_nginx(asset)
  end

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

  def redirect_to_draft_assets_host_for?(asset)
    asset.draft? && !requested_from_draft_assets_host?
  end

  def redirect_to_draft_assets_host
    redirect_to host: AssetManager.govuk.draft_assets_host, format: params[:format]
  end

  def redirect_to_replacement_for(asset)
    redirect_to asset.replacement.public_url_path, status: :moved_permanently
  end

  def add_link_header(asset)
    if asset.parent_document_url
      headers['Link'] = %(<#{asset.parent_document_url}>; rel="up")
    end
  end

  def add_frame_header
    headers['X-Frame-Options'] = 'DENY'
  end

  def filename_current?
    asset.filename == params[:filename]
  end

  def asset_servable?
    asset.filename_valid?(params[:filename]) &&
      asset.uploaded? &&
      asset.mainstream?
  end

  def asset
    @asset ||= Asset.undeleted.find(params[:id])
  end

  def redirect_to_current_filename
    redirect_to(
      action: :download,
      id: params[:id],
      filename: asset.filename,
      only_path: true,
    )
  end

  def temporary_redirect?
    false
  end

  def is_authenticated_for_asset?(asset)
    return true if user_signed_in?

    token = params.fetch(:token, cookies[:auth_bypass_token])
    asset.valid_auth_bypass_token?(token)
  end
end
