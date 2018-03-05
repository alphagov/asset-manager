class WhitehallMediaController < BaseMediaController
  def download
    if redirect_to_draft_assets_host_for?(asset)
      redirect_to_draft_assets_host
      return
    end

    unless asset.accessible_by?(current_user)
      head :forbidden
      return
    end

    if asset.infected?
      error_404
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

    if asset.unscanned? || asset.clean?
      set_expiry(cache_control.expires_in(1.minute))
      if asset.image?
        redirect_to self.class.helpers.image_path('thumbnail-placeholder.png')
      else
        redirect_to '/government/placeholder'
      end
      return
    end

    set_expiry(cache_control)
    add_link_header(asset)
    headers['X-Frame-Options'] = AssetManager.whitehall_frame_options
    proxy_to_s3_via_nginx(asset)
  end

protected

  def asset
    @asset ||= WhitehallAsset.from_params(
      path: params[:path], format: params[:format], path_prefix: 'government/uploads/'
    )
  end

  def cache_control
    AssetManager.whitehall_cache_control
  end
end
