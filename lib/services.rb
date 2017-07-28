require 's3_storage'

module Services
  def self.cloud_storage
    aws_s3_bucket_name = AssetManager::Application.config.aws_s3_bucket_name
    @cloud_storage ||= S3Storage.build(aws_s3_bucket_name)
  end
end
