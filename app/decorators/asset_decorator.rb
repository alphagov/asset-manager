class AssetDecorator < Draper::Decorator

  def as_json(options = {})
    {
      :_response_info => {
        :status => options[:status] || "ok",
      },
      :id => h.asset_url(model.id),
      :name => model.file.file.identifier,
      :content_type => asset_mime_type.to_s,
      :file_url => "#{Plek.new.asset_root}/media/#{model.id}/#{model.file.file.identifier}",
    }
  end

private

  def asset_mime_type
    MIME::Types.type_for(model.file.current_path).first
  end
end
