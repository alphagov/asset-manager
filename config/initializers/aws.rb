AssetManager::Application.config.aws_s3_bucket_name = ENV['AWS_S3_BUCKET_NAME']

Aws.config.update(
  logger: Rails.logger
)
