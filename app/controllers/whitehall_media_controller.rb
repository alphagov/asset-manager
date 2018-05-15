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

    if asset.replacement.present? && (!asset.replacement.draft? || requested_from_draft_assets_host?)
      set_default_expiry
      redirect_to_replacement_for(asset)
      return
    end

    if asset.unscanned? || asset.clean?
      expires_in 1.minute, public: true
      if asset.image?
        redirect_to self.class.helpers.image_path('thumbnail-placeholder.png')
      else
        redirect_to '/government/placeholder'
      end
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

  def asset
    @asset ||= WhitehallAsset.from_params(
      path: params[:path], format: params[:format], path_prefix: 'government/uploads/'
    )
  end
end
