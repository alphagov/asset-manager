require 's3_storage/fake'

class S3Storage
  ObjectNotFoundError = Class.new(StandardError)

  def self.build
    if AssetManager.s3.configured?
      new(AssetManager.s3.bucket_name)
    elsif AssetManager.s3.fake?
      Fake.new(AssetManager.fake_s3.root)
    else
      raise 'AWS S3 bucket not correctly configured'
    end
  end

  def initialize(bucket_name)
    @bucket_name = bucket_name
  end

  def save(asset, force: false)
    metadata = exists?(asset) ? metadata_for(asset) : {}
    if force || metadata['md5-hexdigest'] != asset.md5_hexdigest
      metadata['md5-hexdigest'] = asset.md5_hexdigest
      object_for(asset).upload_file(asset.file.path, metadata: metadata)
    end
  end

  def presigned_url_for(asset, http_method: 'GET')
    object_for(asset).presigned_url(http_method, expires_in: 1.minute)
  end

  def exists?(asset)
    object_for(asset).exists?
  end

  def never_replicated?(asset)
    replication_status(asset).nil?
  end

  def replicated?(asset)
    status = replication_status(asset)
    status && (status == 'COMPLETED')
  end

  def metadata_for(asset)
    result = head_object_for(asset)
    result.metadata
  rescue Aws::S3::Errors::NotFound
    raise ObjectNotFoundError.new("S3 object not found for asset: #{asset.id}")
  end

private

  def replication_status(asset)
    head_object_for(asset).replication_status
  rescue Aws::S3::Errors::NotFound
    raise ObjectNotFoundError.new("S3 object not found for asset: #{asset.id}")
  end

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
