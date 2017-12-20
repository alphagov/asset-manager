require 'services'

class AssetUploadStateWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'low_priority'

  def perform(asset_id)
    asset = Asset.unscoped.find(asset_id)
    if Services.cloud_storage.exists?(asset)
      asset.upload_success!
    end
  end
end
