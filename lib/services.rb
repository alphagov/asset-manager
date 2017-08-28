require 's3_storage'

module Services
  def self.cloud_storage
    @cloud_storage ||= S3Storage.new(AssetManager.aws_s3_bucket_name)
  end
end
