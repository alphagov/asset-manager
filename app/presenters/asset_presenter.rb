class AssetPresenter
  def initialize(asset, view_context)
    @asset = asset
    @view_context = view_context
  end

  def as_json(options = {})
    {
      _response_info: {
        status: options[:status] || "ok",
      },
      id: @view_context.asset_url(@asset.id),
      name: @asset.filename,
      content_type: @asset.content_type,
      file_url: URI.join(Plek.new.asset_root, Addressable::URI.encode(@asset.public_url_path)).to_s,
      state: @asset.state,
    }
  end
end
