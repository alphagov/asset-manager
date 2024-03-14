require "s3_storage/fake"

class S3Storage
  ObjectNotFoundError = Class.new(StandardError)
  ObjectUploadFailedError = Class.new(StandardError)

  def self.build
    if AssetManager.s3.configured?
      new(AssetManager.s3.bucket_name)
    elsif AssetManager.s3.fake?
      Fake.new(AssetManager.fake_s3.root)
    else
      raise "AWS S3 bucket not correctly configured"
    end
  end

  def initialize(bucket_name)
    @bucket_name = bucket_name
  end

  def upload(asset, force: false)
    Rails.logger.info("#{asset.id} - S3Storage#upload")
    metadata = exists?(asset) ? metadata_for(asset) : {}
    Rails.logger.info("#{asset.id} - Remote #{metadata["md5-hexdigest"]} - Model #{asset.md5_hexdigest}")
    if force || metadata["md5-hexdigest"] != asset.md5_hexdigest
      metadata["md5-hexdigest"] = asset.md5_hexdigest
      begin
        Rails.logger.info("#{asset.id} - S3Storage#upload - uploading file")
        unless object_for(asset).upload_file(asset.file.path, metadata:)
          error_message = "Aws::S3::Object#upload_file returned false for asset ID: #{asset.id}"
          raise ObjectUploadFailedError, error_message
        end
      rescue Aws::S3::MultipartUploadError => e
        error_message = "Aws::S3::Object#upload_file raised #{e.inspect} for asset ID: #{asset.id}"
        raise ObjectUploadFailedError, error_message
      end
    end
  end

  def delete(asset)
    object_for(asset).delete
  end

  def presigned_url_for(asset, http_method: "GET")
    object_for(asset).presigned_url(http_method.downcase, expires_in: 60)
  end

  def exists?(asset)
    object_for(asset).exists?
  end

  def never_replicated?(asset)
    replication_status(asset).nil?
  end

  def replicated?(asset)
    status = replication_status(asset)
    status && (status == "COMPLETED")
  end

  def metadata_for(asset)
    result = head_object_for(asset)
    result.metadata
  rescue Aws::S3::Errors::NotFound
    raise ObjectNotFoundError, "S3 object not found for asset: #{asset.id}"
  end

  def healthy?
    response = client.head_bucket({ bucket: @bucket_name })
    # We expect that not being able to connect to the bucket should raise an exception, but the following line
    # guards against the possibility that it returns an unsuccessful response instead as there is some ambiguity in the
    # documentation vs observed behaviour
    response.successful?
  rescue Aws::S3::Errors::ServiceError
    false
  end

private

  def replication_status(asset)
    head_object_for(asset).replication_status
  rescue Aws::S3::Errors::NotFound
    raise ObjectNotFoundError, "S3 object not found for asset: #{asset.id}"
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
