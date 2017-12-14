AssetManager.aws_s3_bucket_name = if Rails.env.production?
                                    ENV.fetch('AWS_S3_BUCKET_NAME')
                                  else
                                    ENV['AWS_S3_BUCKET_NAME']
                                  end

Aws.config.update(
  logger: Rails.logger
)
