require 'services'

class SaveToCloudStorageWorker
  include Sidekiq::Worker

  def perform(asset_id)
    asset = Asset.undeleted.find(asset_id)
    unless asset.uploaded?
      Services.cloud_storage.save(asset)
      asset.upload_success!
    end
  end
end
