module ApplicationHelper

  def asset_mime_type(asset)
    MIME::Types.type_for(asset.file.current_path).first
  end
end
