class S3Uploader
  def initialize(asset)
    @asset = asset
  end

  def upload
    s3_resource = Aws::S3::Resource.new
    bucket = s3_resource.bucket(ENV['BUCKET_NAME'])
    object = bucket.object(@asset.id.to_s)
    object.upload_file(@asset.file.path)
  end
end
