class WhitehallMediaController < BaseMediaController
  def download
    path = "/government/uploads/#{params[:path]}.#{params[:format]}"
    asset = WhitehallAsset.find_by(legacy_url_path: path)

    if asset.unscanned?
      set_expiry(1.minute)
      if asset.image?
        redirect_to self.class.helpers.image_path('thumbnail-placeholder.png')
      else
        redirect_to '/government/placeholder'
      end
      return
    elsif asset.infected?
      error_404
      return
    end

    set_expiry(AssetManager.whitehall_cache_control.max_age)
    headers['X-Frame-Options'] = AssetManager.whitehall_frame_options
    if proxy_to_s3_via_nginx?
      proxy_to_s3_via_nginx(asset)
    else
      serve_from_nfs_via_nginx(asset)
    end
  end

protected

  def proxy_percentage_of_asset_requests_to_s3_via_nginx
    100
  end
end
