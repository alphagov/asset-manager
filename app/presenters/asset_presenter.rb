class AssetPresenter

  def initialize(asset, view_context)
    @asset = asset
    @view_context = view_context
  end

  def as_json(options = {})
    {
      :_response_info => {
        :status       => options[:status] || "ok",
      },
      :id             => @view_context.asset_url(@asset.id),
      :name           => @asset.file.to_s.split('/').last,
      :content_type   => asset_mime_type.to_s,
      :file_url       => @asset.file_url,
      :state          => @asset.state,
      :title          => @asset.title,
      :source         => @asset.source,
      :description    => @asset.description,
      :creator        => @asset.creator,
      :subject        => @asset.subject,
      :license        => @asset.license,
    }
  end

private

  def asset_mime_type
    MIME::Types.type_for(@asset.file.current_path).first
  end
end
