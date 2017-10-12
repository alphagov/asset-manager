class WhitehallMediaController < BaseMediaController
  include ActionView::Helpers::AssetUrlHelper

  def download
    path = "/government/uploads/#{params[:path]}.#{params[:format]}"
    asset = WhitehallAsset.find_by(legacy_url_path: path)

    if asset.unscanned?
      set_expiry(1.minute)
      if asset.image?
        redirect_to image_path('thumbnail-placeholder.png')
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
    serve_from_nfs_via_nginx(asset)
  end

protected

  def serve_from_nfs_via_nginx(asset)
    send_file(asset.file.path, disposition: AssetManager.content_disposition.type)
  end
end
