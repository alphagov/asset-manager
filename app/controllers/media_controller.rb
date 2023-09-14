# frozen_string_literal: true

class MediaController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_token_payload

  def download
    if asset.replacement.present? && (!asset.replacement.draft? || requested_from_draft_assets_host?)
      set_default_expiry
      redirect_to_replacement_for(asset)
      return
    end

    if redirect_to_draft_assets_host_for?(asset)
      redirect_to_draft_assets_host
      return
    end

    unless authorized_for_asset?(asset)
      error_403
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

    if temporary_redirect?
      perform_temporary_redirect
      return
    end

    if requested_from_draft_assets_host? || requested_from_internal_host?
      expires_now
    else
      set_default_expiry
    end
    add_link_header(asset)
    add_frame_header
    proxy_to_s3_via_nginx(asset)
  rescue Mongoid::Errors::DocumentNotFound
    if (requested_from_draft_assets_host? || requested_from_internal_host?) && !user_signed_in?
      authenticate_user!
    else
      raise
    end
  end

protected

  def has_bypass_id_for_asset?(asset)
    return false if @token_payload.nil?

    asset.valid_auth_bypass_token?(@token_payload["sub"])
  end

  def authorized_for_asset?(asset)
    return true unless requested_from_draft_assets_host? || requested_from_internal_host?

    return true if has_bypass_id_for_asset?(asset)

    return true if draft_asset_manager_access? && !asset.access_limited?

    authenticate_user!
    asset.accessible_by?(current_user)
  end

  def requested_from_draft_assets_host?
    request.host == AssetManager.govuk.draft_assets_host
  end

  def requested_from_internal_host?
    request.host == URI.parse(Plek.find("asset-manager")).host
  end

  def draft_asset_manager_access?
    return false if @token_payload.nil?

    @token_payload["draft_asset_manager_access"] == true
  end

  def proxy_to_s3_via_nginx(asset)
    headers["ETag"] = %("#{asset.etag}")
    headers["Last-Modified"] = asset.last_modified.httpdate
    headers["Content-Disposition"] = AssetManager.content_disposition.header_for(asset)

    if request.fresh?(response)
      head :not_modified
    elsif AssetManager.s3.fake?
      url = Services.cloud_storage.presigned_url_for(asset, http_method: request.request_method)
      redirect_to url
    else
      url = Services.cloud_storage.presigned_url_for(asset, http_method: request.request_method)
      headers["X-Accel-Redirect"] = "/cloud-storage-proxy/#{url}"
      head :ok, content_type: content_type(asset)
    end
  end

  def content_type(asset)
    asset.content_type || asset.content_type_from_extension
  end

  def redirect_to_draft_assets_host_for?(asset)
    asset.draft? && !requested_from_draft_assets_host? && !requested_from_internal_host?
  end

  def redirect_to_draft_assets_host
    redirect_to host: AssetManager.govuk.draft_assets_host,
                format: params[:format],
                params: request.query_parameters
  end

  def redirect_to_replacement_for(asset)
    # explicitly use the external asset host
    target_host =
      if asset.replacement.draft?
        AssetManager.govuk.draft_assets_host
      else
        AssetManager.govuk.assets_host
      end

    redirect_to "//#{target_host}#{asset.replacement.public_url_path}",
                status: :moved_permanently
  end

  def add_link_header(asset)
    if asset.parent_document_url
      headers["Link"] = %(<#{asset.parent_document_url}>; rel="up")
    end
  end

  def add_frame_header
    headers["X-Frame-Options"] = "DENY"
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

  def set_token_payload
    token = params.fetch(:token, cookies[:auth_bypass_token])
    @token_payload = if token
                       secret = Rails.application.secrets.jwt_auth_secret
                       JWT.decode(token, secret, true, algorithm: "HS256").first
                     end
  rescue JWT::DecodeError
    @token_payload = nil
  end
end
