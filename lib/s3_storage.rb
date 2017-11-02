require 's3_storage/fake'
require 's3_storage/null'

class S3Storage
  NotConfiguredError = Class.new(StandardError)
  ObjectNotFoundError = Class.new(StandardError)

  def self.build(bucket_name)
    if bucket_name.present?
      new(bucket_name)
    elsif Rails.env.development?
      Fake.new(AssetManager.fake_s3_root)
    else
      Null.new
    end
  end

  def initialize(bucket_name)
    @bucket_name = bucket_name
  end

  def save(asset)
    metadata = exists?(asset) ? metadata_for(asset) : {}
    unless metadata['md5-hexdigest'] == asset.md5_hexdigest
      metadata['md5-hexdigest'] = asset.md5_hexdigest
      object_for(asset).upload_file(asset.file.path, metadata: metadata)
    end
  end

  def presigned_url_for(asset, http_method: 'GET')
    options = {
      expires_in: 1.minute,
      virtual_host: AssetManager.aws_s3_use_virtual_host
    }
    object_for(asset).presigned_url(http_method, options)
  end

  def exists?(asset)
    object_for(asset).exists?
  end

  def metadata_for(asset)
    result = head_object_for(asset)
    result.metadata
  rescue Aws::S3::Errors::NotFound
    raise ObjectNotFoundError.new("S3 object not found for asset: #{asset.id}")
  end

private

  def object_for(asset)
    Aws::S3::Object.new(bucket_name: @bucket_name, key: asset.uuid)
  end

  def head_object_for(asset)
    client.head_object(bucket: @bucket_name, key: asset.uuid)
  end

  def client
    Aws::S3::Client.new
  end
end
