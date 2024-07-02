class DeleteAssetFileFromNfsWorker
  include Sidekiq::Worker
  sidekiq_options queue: "low_priority"

  def perform(asset_id)
    asset = Asset.find(asset_id)
    if asset.uploaded?
      FileUtils.rm_rf(File.dirname(asset.file.path))
      Rails.logger.info("#{asset.id} - DeleteAssetFileFromNfsWorker - File removed")
    end
  end
end
