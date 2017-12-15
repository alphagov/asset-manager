require 's3_configuration'

AssetManager.s3 = S3Configuration.build

Aws.config.update(
  logger: Rails.logger
)
