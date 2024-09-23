require "services"

class SaveToCloudStorageJob
  include Sidekiq::Job

  def perform(asset_id)
    asset = Asset.undeleted.find(asset_id)
    unless asset.uploaded?
      Services.cloud_storage.upload(asset)
      asset.upload_success!
    end
  end
end
