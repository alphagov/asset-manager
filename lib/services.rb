require 's3_storage'

module Services
  def self.cloud_storage
    # rubocop:disable Style/VariableNumber
    aws_s3_bucket_name = AssetManager::Application.config.aws_s3_bucket_name
    # rubocop:enable Style/VariableNumber
    @cloud_storage ||= S3Storage.build(aws_s3_bucket_name)
  end
end
