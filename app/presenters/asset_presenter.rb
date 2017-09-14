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
      file_url: "#{Plek.new.asset_root}/media/#{@asset.id}/#{@asset.filename}",
      state: @asset.state,
    }
  end
end
