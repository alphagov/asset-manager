AssetManager::Application.config.aws_s3_bucket_name = ENV['AWS_S3_BUCKET_NAME']
AssetManager::Application.config.stream_all_assets_from_s3 = ENV['STREAM_ALL_ASSETS_FROM_S3'].present?

Aws.config.update(
  logger: Rails.logger
)
