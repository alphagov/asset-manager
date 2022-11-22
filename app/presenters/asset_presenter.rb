class AssetPresenter
  def initialize(asset, view_context)
    @asset = asset
    @view_context = view_context
  end

  def as_json(options = {})
    json = {
      _response_info: {
        status: options[:status] || "ok",
      },
      id: @view_context.asset_url(@asset.id),
      name: @asset.filename,
      content_type: @asset.content_type || @asset.content_type_from_extension,
      size: @asset.size,
      file_url: URI.join(Plek.asset_root, Addressable::URI.encode(@asset.public_url_path)).to_s,
      state: @asset.state,
      draft: @asset.draft?,
      deleted: @asset.deleted?,
    }
    if @asset.redirect_url.present?
      json[:redirect_url] = @asset.redirect_url
    end
    if @asset.replacement.present?
      json[:replacement_id] = @asset.replacement_id.to_s
    end
    if @asset.parent_document_url.present?
      json[:parent_document_url] = @asset.parent_document_url.to_s
    end
    json
  end
end
