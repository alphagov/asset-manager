class BaseMediaController < ApplicationController
  skip_before_filter :require_signin_permission!

protected

  def serve_from_nfs_via_nginx(asset)
    send_file(asset.file.path, disposition: AssetManager.content_disposition.type)
  end
end
