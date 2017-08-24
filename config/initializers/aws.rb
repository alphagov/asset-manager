AssetManager.aws_s3_bucket_name = ENV['AWS_S3_BUCKET_NAME']
AssetManager.aws_s3_use_virtual_host = ENV['AWS_S3_USE_VIRTUAL_HOST'].present?

Aws.config.update(
  logger: Rails.logger
)
