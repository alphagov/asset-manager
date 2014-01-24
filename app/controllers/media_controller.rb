class MediaController < ApplicationController
  before_filter :authenticate_if_private

  def download
    unless asset.file.file.identifier == params[:filename] and asset.clean?
      error_404
      return
    end

    unless asset.accessible_by?(current_user)
      if private?
        error 403, "Forbidden"
      else
        error_404
      end

      return
    end

    respond_to do |format|
      format.any do
        set_expiry(24.hours)
        send_file(asset.file.path, :disposition => 'inline')
      end
    end
  end

protected

  def authenticate_if_private
    authenticate_user! if requested_via_private_vhost?
  end

  def asset
    @asset ||= Asset.find(params[:id])
  end

  def requested_via_private_vhost?
    request.host.include? 'private'
  end

end
