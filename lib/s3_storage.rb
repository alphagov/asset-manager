class S3Storage
  class Null
    def save(_asset)
    end

    def load(_asset)
      StringIO.new
    end
  end

  def self.build(bucket_name)
    bucket_name.present? ? new(bucket_name) : Null.new
  end

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
