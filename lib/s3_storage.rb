class S3Storage
  def initialize(bucket_name)
    @bucket_name = bucket_name
  end

  def save(asset)
    object = Aws::S3::Object.new(bucket_name: @bucket_name, key: asset.id.to_s)
    object.upload_file(asset.file.path)
  end
end
