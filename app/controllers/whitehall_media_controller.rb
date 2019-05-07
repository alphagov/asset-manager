class WhitehallMediaController < MediaController
protected # rubocop:disable Layout/IndentationWidth

  class WhitehallAssetNotFound < StandardError
  end

  rescue_from WhitehallAssetNotFound, with: :error_404

  def asset
    @asset ||= WhitehallAsset.undeleted.from_params(
      path: params[:path], format: params[:format], path_prefix: 'government/uploads/'
    ) || raise(WhitehallAssetNotFound)
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
      redirect_to self.class.helpers.image_path('thumbnail-placeholder.png')
    else
      redirect_to '/government/placeholder'
    end
  end
end
