class MediaController < ApplicationController
  skip_before_filter :require_signin_permission!
  before_filter :authenticate_if_private

  def download
    unless asset_servable?
      error_404
      return
    end

    unless filename_current?
      redirect_to_current_filename
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

  def filename_current?
    asset.filename == params[:filename]
  end

  def asset_servable?
    asset.filename_valid?(params[:filename]) &&
      asset.clean? &&
      asset.accessible_by?(current_user)
  end

  def authenticate_if_private
    require_signin_permission! if requested_via_private_vhost?
  end

  def asset
    @asset ||= Asset.find(params[:id])
  end

  def requested_via_private_vhost?
    request.host == ENV['PRIVATE_ASSET_MANAGER_HOST']
  end

  def redirect_to_current_filename
    redirect_to(
      :action => :download,
      id: params[:id],
      filename: asset.filename,
    )
  end
end
