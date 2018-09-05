require 'services'

class SaveToCloudStorageWorker
  include Sidekiq::Worker

  def perform(asset_id)
    asset = Asset.undeleted.find(asset_id)
    unless asset.uploaded?
      Services.cloud_storage.save(asset)
      asset.upload_success!

      # if we're using real s3, the uploaded file is no longer
      # required
      unless AssetManager.s3.fake?
        DeleteAssetFileFromNfsWorker.perform_async(asset_id)
      end
    end
  end
end
