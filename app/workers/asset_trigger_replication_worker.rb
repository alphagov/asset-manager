class AssetTriggerReplicationWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'low_priority'

  KEY = 'replication-triggered-at'.freeze

  def initialize(cloud_storage: Services.cloud_storage)
    @cloud_storage = cloud_storage
  end

  def perform(asset_id)
    asset = Asset.find(asset_id)
    if @cloud_storage.exists?(asset) && @cloud_storage.never_replicated?(asset)
      @cloud_storage.add_metadata_to(asset, key: KEY, value: Time.now.httpdate)
      @cloud_storage.remove_metadata_from(asset, key: KEY)
    end
  end
end
