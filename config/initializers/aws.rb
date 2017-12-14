require 's3_configuration'

AssetManager.s3 = S3Configuration.new

Aws.config.update(
  logger: Rails.logger
)
