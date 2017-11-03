require 'asset_processor'
require 'asset_replication_checker'

namespace :govuk_assets do
  processor = AssetProcessor.new

  desc 'Store values generated from file metadata for all GOV.UK assets'
  task store_values_generated_from_file_metadata: :environment do
    processor.process_all_assets_with do |asset_id|
      AssetFileMetadataWorker.perform_async(asset_id)
    end
  end

  desc 'Trigger replication for all non-replicated GOV.UK assets'
  task trigger_replication_for_non_replicated_assets: :environment do
    processor.process_all_assets_with do |asset_id|
      AssetTriggerReplicationWorker.perform_async(asset_id)
    end
  end

  desc 'Check all GOV.UK assets have been replicated'
  task check_all_assets_have_been_replicated: :environment do
    checker = AssetReplicationChecker.new
    checker.check_all_assets
  end
end
