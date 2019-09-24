class SetAssetSizeWorker
  include Sidekiq::Worker
  sidekiq_options queue: "low_priority"

  def perform(asset_id)
    asset = Asset.find(asset_id)
    size_from_etag = asset.etag.split("-").last.to_i(16)
    asset.set(size: size_from_etag)
  end
end
