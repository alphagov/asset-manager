class WhitehallMediaController < ApplicationController
  skip_before_filter :require_signin_permission!

  def download
    path = "/government/uploads/#{params[:path]}.#{params[:format]}"
    asset = Asset.find_by(legacy_url_path: path)

    unless asset.clean?
      error_404
      return
    end

    send_file(asset.file.path, disposition: AssetManager.content_disposition.type)
  end
end
