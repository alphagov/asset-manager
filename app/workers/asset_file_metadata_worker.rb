class AssetFileMetadataWorker
  include Sidekiq::Worker

  def perform(asset_id)
    asset = Asset.find(asset_id)
    asset.set(
      etag: asset.etag_from_file,
      last_modified: asset.last_modified_from_file,
      md5_hexdigest: asset.md5_hexdigest_from_file
    )
  end
end
