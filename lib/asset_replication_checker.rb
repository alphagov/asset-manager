require 'services'

class AssetReplicationChecker
  def initialize(cloud_storage: Services.cloud_storage)
    @cloud_storage = cloud_storage
    @processor = AssetProcessor.new
  end

  def check_all_assets
    @ids_of_assets_with_no_s3_object = []
    @ids_of_assets_with_s3_object_not_replicated = []
    @processor.process_all_assets_with do |asset_id|
      check(asset_id)
    end
    puts "Assets with no S3 object: #{@ids_of_assets_with_no_s3_object}"
    puts "Assets with S3 object not replicated: #{@ids_of_assets_with_s3_object_not_replicated}"
  end

  def check(asset_id)
    asset = Asset.find(asset_id)
    if @cloud_storage.exists?(asset)
      unless @cloud_storage.replicated?(asset)
        @ids_of_assets_with_s3_object_not_replicated << asset_id
      end
    else
      @ids_of_assets_with_no_s3_object << asset_id
    end
  end
end
