class MediaController < BaseMediaController
  def download
    if redirect_to_draft_assets_host_for?(asset)
      redirect_to_draft_assets_host
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

    if asset.replacement.present?
      set_expiry(cache_control)
      redirect_to_replacement_for(asset)
      return
    end

    respond_to do |format|
      format.any do
        if requested_from_draft_assets_host?
          expires_now
        else
          set_expiry(cache_control)
        end
        add_link_header(asset)
        headers['X-Frame-Options'] = AssetManager.frame_options
        proxy_to_s3_via_nginx(asset)
      end
    end
  end

protected

  def filename_current?
    asset.filename == params[:filename]
  end

  def asset_servable?
    asset.filename_valid?(params[:filename]) &&
      asset.uploaded? &&
      asset.mainstream?
  end

  def asset
    @asset ||= Asset.find(params[:id])
  end

  def redirect_to_current_filename
    redirect_to(
      action: :download,
      id: params[:id],
      filename: asset.filename,
      only_path: true,
    )
  end

  def cache_control
    AssetManager.cache_control
  end
end
