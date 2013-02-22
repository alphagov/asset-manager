class MediaController < ApplicationController
  rescue_from Mongoid::Errors::DocumentNotFound, :with => :error_404
  rescue_from BSON::InvalidObjectId, :with => :error_404

  before_filter { set_expiry(24.hours) }

  def download
    @asset = Asset.find(params[:id])
    error_404 if @asset.nil? || @asset.file.file.identifier != params[:filename]

    respond_to do |format|
      format.any { send_file(@asset.file.path) }
    end
  end

  def redirect
    @asset = Asset.find(params[:id])
    error_404 if @asset.nil?

    redirect_to(:action => "download", :status => 301,
                :id => @asset.id, :filename => @asset.file.file.identifier)
  end
end
