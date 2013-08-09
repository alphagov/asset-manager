class MediaController < ApplicationController
  skip_before_filter :authenticate_user!
  skip_before_filter :require_signin_permission!

  def download
    @asset = Asset.find(params[:id])
    unless @asset.file.to_s.split('/').last == params[:filename] and @asset.clean?
      error_404
      return
    end

    respond_to do |format|
      format.any do
        redirect_to @asset.file.to_s
      end
    end
  end

  protected

  def set_expiry(duration)
    unless Rails.env.development?
      expires_in duration, :public => true
    end
  end
end
