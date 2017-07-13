class S3Uploader
  def initialize(asset)
    @asset = asset
  end

  def upload
    object = Aws::S3::Object.new(bucket_name: Rails.configuration.bucket_name, key: @asset.id.to_s)
    object.upload_file(@asset.file.path)
  rescue => e
    Airbrake.notify_or_ignore(e, params: { id: @asset.id.to_s, file: @asset.file.path })
    raise
  end
end
