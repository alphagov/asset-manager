namespace :govuk_assets do
  desc 'Store values generated from file metadata for all GOV.UK assets'
  task store_values_generated_from_file_metadata: :environment do
    process_all_assets_with do |asset_id|
      AssetFileMetadataWorker.perform_async(asset_id)
    end
  end

  desc 'Trigger replication for all non-replicated GOV.UK assets'
  task trigger_replication_for_non_replicated_assets: :environment do
    process_all_assets_with do |asset_id|
      AssetTriggerReplicationWorker.perform_async(asset_id)
    end
  end

  def process_all_assets_with
    STDOUT.sync = true
    asset_ids = Asset.pluck(:id).to_a
    total = asset_ids.count
    asset_ids.each_with_index do |asset_id, index|
      percent = "%0.0f" % (index / total.to_f * 100)
      if (index % 1000).zero?
        puts "#{index} of #{total} (#{percent}%) assets"
      end
      yield asset_id.to_s
    end
    puts "\nFinished!"
  end
end
