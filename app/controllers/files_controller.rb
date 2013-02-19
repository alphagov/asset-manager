class FilesController < ApplicationController
  rescue_from Mongoid::Errors::DocumentNotFound, :with => :error_404
  rescue_from BSON::InvalidObjectId, :with => :error_404

  def download
    @asset = Asset.find(params[:id])
    error_404 if @asset.nil? || @asset.file.file.identifier != params[:filename]

    respond_to do |format|
      format.any { send_file(@asset.file.path, :x_sendfile => true) }
    end
  end
end
