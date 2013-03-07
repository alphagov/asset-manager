class MediaController < ApplicationController
  skip_before_filter :authenticate_user!
  skip_before_filter :require_signin_permission!

  def download
    @asset = Asset.find(params[:id])
    unless @asset.file.file.identifier == params[:filename]
      error_404
      return
    end

    respond_to do |format|
      format.any do
        set_expiry(24.hours)
        send_file(@asset.file.path, :disposition => 'inline')
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
