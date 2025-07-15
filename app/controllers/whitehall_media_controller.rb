class WhitehallMediaController < MediaController
protected

  class WhitehallAssetNotFound < StandardError; end
  class WhitehallAssetDeleted < StandardError; end

  rescue_from WhitehallAssetNotFound, with: :error_404
  rescue_from WhitehallAssetDeleted, with: :error_410

  def asset
    @asset ||= WhitehallAsset.from_params(
      path: params[:path], format: params[:format], path_prefix: "government/uploads/",
    )
    if @asset.nil?
      raise WhitehallAssetNotFound
    elsif @asset.deleted?
      raise WhitehallAssetDeleted
    end

    @asset
  end

  def asset_servable?
    !asset.infected?
  end

  def filename_current?
    true
  end

  def temporary_redirect?
    asset.unscanned? || asset.clean?
  end

  def perform_temporary_redirect
    expires_in 1.minute, public: true
    if asset.image?
      redirect_to self.class.helpers.image_path("thumbnail-placeholder.png")
    else
      redirect_to "/government/placeholder"
    end
  end
end
