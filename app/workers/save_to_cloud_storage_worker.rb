require 'services'

class SaveToCloudStorageWorker
  include Sidekiq::Worker

  def perform(asset_id)
    asset = Asset.find(asset_id)
    Services.cloud_storage.save(asset)
    asset.upload_success!
  rescue CloudStorage::ObjectUploadFailedError
    asset.upload_failure!
    raise
  end
end
