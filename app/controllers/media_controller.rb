class MediaController < ApplicationController
  skip_before_filter :require_signin_permission!
  before_filter :authenticate_if_private

  def download
    unless asset_present_and_clean? && asset.accessible_by?(current_user)
      error_404
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
    require_signin_permission! if requested_via_private_vhost?
  end

  def asset
    @asset ||= Asset.find(params[:id])
  end

  def requested_via_private_vhost?
    request.host.include? 'private'
  end

  def asset_present_and_clean?
    asset.file.file.identifier == params[:filename] and asset.clean?
  end

end
