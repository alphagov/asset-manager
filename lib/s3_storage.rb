class S3Storage
  def initialize(bucket_name)
    @bucket_name = bucket_name
  end

  def save(asset)
    object_for(asset).upload_file(asset.file.path)
  end

  def load(asset)
    object_for(asset).get.body
  end

private

  def object_for(asset)
    Aws::S3::Object.new(bucket_name: @bucket_name, key: asset.id.to_s)
  end
end
