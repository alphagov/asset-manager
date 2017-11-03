class AssetTriggerReplicationWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'low_priority'

  def initialize(cloud_storage: Services.cloud_storage)
    @cloud_storage = cloud_storage
  end

  def perform(asset_id)
    asset = Asset.find(asset_id)
    if @cloud_storage.exists?(asset) && @cloud_storage.never_replicated?(asset)
      @cloud_storage.save(asset, force: true)
    end
  end
end
