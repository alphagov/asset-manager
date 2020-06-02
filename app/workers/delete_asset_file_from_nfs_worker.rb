class DeleteAssetFileFromNfsWorker
  include Sidekiq::Worker
  sidekiq_options queue: "low_priority"

  def perform(asset_id)
    asset = Asset.find(asset_id)
    if asset.uploaded?
      asset.delete_file_from_nfs
    end
  end
end
