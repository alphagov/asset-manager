class SaveToCloudStorageWorker
  include Sidekiq::Worker

  def perform(asset_id)
    asset = Asset.find(asset_id)
    Services.cloud_storage.save(asset)
  rescue => e
    Airbrake.notify_or_ignore(e, params: { id: asset.id, filename: asset.filename })
    raise
  end
end
