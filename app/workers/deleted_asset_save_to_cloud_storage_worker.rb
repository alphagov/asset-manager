require 'services'

class DeletedAssetSaveToCloudStorageWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'low_priority'

  def initialize(cloud_storage: Services.cloud_storage)
    @cloud_storage = cloud_storage
  end

  def perform(asset_id)
    asset = Asset.unscoped.find(asset_id)
    @cloud_storage.save(asset)
  end
end
