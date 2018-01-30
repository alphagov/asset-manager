class WhitehallMediaController < BaseMediaController
  def download
    if redirected_to_draft_assets_host_for?(asset)
      return
    end

    if asset.infected?
      error_404
      return
    end

    if asset.unscanned? || asset.clean?
      set_expiry(1.minute)
      if asset.image?
        redirect_to self.class.helpers.image_path('thumbnail-placeholder.png')
      else
        redirect_to '/government/placeholder'
      end
      return
    end

    set_expiry(AssetManager.whitehall_cache_control.max_age)
    headers['X-Frame-Options'] = AssetManager.whitehall_frame_options
    proxy_to_s3_via_nginx(asset)
  end

protected

  def asset
    @asset ||= begin
      path = "/government/uploads/#{params[:path]}"
      path += ".#{params[:format]}" if params[:format].present?
      WhitehallAsset.find_by(legacy_url_path: path)
    end
  end
end
