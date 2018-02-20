class SetAssetSizeWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'low_priority'

  def perform(asset_id)
    Asset.unscoped.find(asset_id).set_size_from_etag
  end
end
