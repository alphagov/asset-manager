require 'cloud_storage'

class S3Storage
  NotConfiguredError = Class.new(CloudStorage::NotConfiguredError)

  NOT_CONFIGURED_ERROR_MESSAGE = 'AWS S3 bucket not correctly configured'.freeze

  class Null
    def save(_asset, _options = {}); end

    def load(_asset)
      raise NotConfiguredError.new(NOT_CONFIGURED_ERROR_MESSAGE)
    end

    def public_url_for(_asset)
      raise NotConfiguredError.new(NOT_CONFIGURED_ERROR_MESSAGE)
    end

    def presigned_url_for(_asset, _http_method: 'GET')
      raise NotConfiguredError.new(NOT_CONFIGURED_ERROR_MESSAGE)
    end
  end

  def self.build(bucket_name)
    bucket_name.present? ? new(bucket_name) : Null.new
  end

  def initialize(bucket_name)
    @bucket_name = bucket_name
  end

  def save(asset, options = {})
    unless md5_from_metadata_for(asset) == asset.md5_hexdigest
      s3_options = { metadata: { 'md5-hexdigest' => asset.md5_hexdigest } }.merge(options)
      object_for(asset).upload_file(asset.file.path, s3_options)
    end
  end

  def load(asset)
    object_for(asset).get.body
  end

  def public_url_for(asset)
    object_for(asset).public_url(virtual_host: AssetManager.aws_s3_use_virtual_host)
  end

  def presigned_url_for(asset, http_method: 'GET')
    object_for(asset).presigned_url(http_method, expires_in: 1.minute, virtual_host: AssetManager.aws_s3_use_virtual_host)
  end

private

  def object_for(asset)
    Aws::S3::Object.new(bucket_name: @bucket_name, key: asset.uuid)
  end

  def head_object_for(asset)
    client.head_object(bucket: @bucket_name, key: asset.uuid)
  end

  def md5_from_metadata_for(asset)
    result = head_object_for(asset)
    result.metadata['md5-hexdigest']
  rescue Aws::S3::Errors::NotFound
    nil
  end

  def client
    Aws::S3::Client.new
  end
end
