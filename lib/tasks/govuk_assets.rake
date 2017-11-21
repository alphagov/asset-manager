require 'asset_processor'
require 'asset_replication_checker'

# rubocop:disable Metrics/BlockLength
namespace :govuk_assets do
  desc 'Store values generated from file metadata for all GOV.UK assets'
  task store_values_generated_from_file_metadata: :environment do
    processor = AssetProcessor.new
    processor.process_all_assets_with do |asset_id|
      AssetFileMetadataWorker.perform_async(asset_id)
    end
  end

  desc 'Store values generated from file metadata for GOV.UK assets marked as deleted'
  task store_values_generated_from_file_metadata_for_assets_marked_as_deleted: :environment do
    processor = AssetProcessor.new(scope: Asset.deleted, report_progress_every: 100)
    processor.process_all_assets_with do |asset_id|
      DeletedAssetFileMetadataWorker.perform_async(asset_id)
    end
  end

  desc 'Trigger replication for all non-replicated GOV.UK assets'
  task trigger_replication_for_non_replicated_assets: :environment do
    processor = AssetProcessor.new
    processor.process_all_assets_with do |asset_id|
      AssetTriggerReplicationWorker.perform_async(asset_id)
    end
  end

  desc 'Check all GOV.UK assets have been replicated'
  task check_all_assets_have_been_replicated: :environment do
    checker = AssetReplicationChecker.new
    checker.check_all_assets
  end

  desc 'Upload GOV.UK assets marked as deleted to cloud storage'
  task upload_assets_marked_as_deleted_to_cloud_storage: :environment do
    processor = AssetProcessor.new(scope: Asset.deleted, report_progress_every: 100)
    processor.process_all_assets_with do |asset_id|
      DeletedAssetSaveToCloudStorageWorker.perform_async(asset_id)
    end
  end

  desc 'Permanently delete asset by ID (asset must already be marked as deleted)'
  task :permanently_delete_asset, [:asset_id] => :environment do |_, args|
    asset_id = args.fetch(:asset_id) do
      raise '*** Error: Please supply asset_id argument to Rake task'
    end
    asset = Asset.unscoped.where(id: asset_id).first
    if asset.present?
      if asset.deleted?
        print "Permanently deleting asset ID: #{asset_id}..."
        asset.destroy!
        puts '[OK]'
      else
        raise "*** Error: Asset not marked as deleted: #{asset_id}"
      end
    else
      raise "*** Error: Asset not found: #{asset_id}"
    end
  end
end
# rubocop:enable Metrics/BlockLength
