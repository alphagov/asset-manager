require 'asset_processor'

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
end
