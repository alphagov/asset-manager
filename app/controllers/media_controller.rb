class MediaController < ApplicationController
  skip_before_filter :require_signin_permission!
  before_filter :authenticate_if_private

  def download
    unless filename_correct?
      return redirect_to_correct_filename
    end

    unless asset.clean? && asset.accessible_by?(current_user)
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
    request.host == ENV['PRIVATE_ASSET_MANAGER_HOST']
  end

  def filename_correct?
    asset.file.file.identifier == params[:filename]
  end

  def redirect_to_correct_filename
    redirect_to(
      :action => :download,
      id: params[:id],
      filename: File.basename(asset.file.path),
    )
  end
end
