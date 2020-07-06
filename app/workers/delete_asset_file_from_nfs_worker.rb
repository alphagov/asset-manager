class DeleteAssetFileFromNfsWorker
  include Sidekiq::Worker
  sidekiq_options queue: "low_priority"

  def perform(asset_id)
    asset = Asset.find(asset_id)
    asset_path = asset.file.path
    if asset.uploaded?
      asset.remove_file!
      FileUtils.rmdir(File.dirname(asset_path))
    end
  end
end
