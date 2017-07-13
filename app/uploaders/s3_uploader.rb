class S3Uploader
  def initialize(asset)
    @asset = asset
  end

  def upload
    s3_resource = Aws::S3::Resource.new
    bucket = s3_resource.bucket(ENV['BUCKET_NAME'])
    object = bucket.object(@asset.id.to_s)
    object.upload_file(@asset.file.path)
  rescue => e
    Airbrake.notify_or_ignore(e, params: { id: @asset.id.to_s, file: @asset.file.path })
    raise
  end
end
