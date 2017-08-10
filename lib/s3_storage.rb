require 'cloud_storage'

class S3Storage
  NotConfiguredError = Class.new(CloudStorage::NotConfiguredError)

  class Null
    def save(_asset, _options = {}); end

    def load(_asset)
      raise NotConfiguredError.new('AWS S3 bucket not correctly configured')
    end
  end

  def self.build(bucket_name)
    bucket_name.present? ? new(bucket_name) : Null.new
  end

  def initialize(bucket_name)
    @bucket_name = bucket_name
  end

  def save(asset, options = {})
    object_for(asset).upload_file(asset.file.path, options)
  end

  def load(asset)
    object_for(asset).get.body
  end

  def public_url_for(asset)
    object_for(asset).public_url(virtual_host: AssetManager.aws_s3_use_virtual_host)
  end

  def presigned_url_for(asset)
    object_for(asset).presigned_url(:get, expires_in: 1.minute, virtual_host: AssetManager.aws_s3_use_virtual_host)
  end

private

  def object_for(asset)
    Aws::S3::Object.new(bucket_name: @bucket_name, key: asset.id.to_s)
  end
end
