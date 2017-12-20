require 'services'

class AssetUploadStateWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'low_priority'

  def perform(asset_id)
    asset = Asset.find(asset_id)
    if Services.cloud_storage.exists?(asset)
      asset.upload_success!
    else
      asset.upload_failure!
    end
  end
end
