class MediaController < BaseMediaController
  def download
    if redirect_to_draft_assets_host_for?(asset)
      redirect_to_draft_assets_host
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

    respond_to do |format|
      format.any do
        set_expiry(AssetManager.cache_control.max_age)
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
end
