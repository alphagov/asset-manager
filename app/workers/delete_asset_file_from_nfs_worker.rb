class DeleteAssetFileFromNfsWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'low_priority'

  def perform(asset_id)
    asset = Asset.unscoped.find(asset_id)
    if asset.uploaded?
      asset.remove_file!
    end
  end
end
