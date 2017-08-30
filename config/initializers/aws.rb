AssetManager.aws_s3_bucket_name = if Rails.env.production?
  ENV.fetch('AWS_S3_BUCKET_NAME')
else
  ENV['AWS_S3_BUCKET_NAME']
end

AssetManager.aws_s3_use_virtual_host = ENV['AWS_S3_USE_VIRTUAL_HOST'].present?

Aws.config.update(
  logger: Rails.logger
)
