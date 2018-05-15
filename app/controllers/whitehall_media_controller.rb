class WhitehallMediaController < MediaController

protected

  def asset
    @asset ||= WhitehallAsset.from_params(
      path: params[:path], format: params[:format], path_prefix: 'government/uploads/'
    )
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
