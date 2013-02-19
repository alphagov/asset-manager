class FilesController < ApplicationController
  rescue_from Mongoid::Errors::DocumentNotFound, :with => :error_404
  rescue_from BSON::InvalidObjectId, :with => :error_404

  def download
  end
end
