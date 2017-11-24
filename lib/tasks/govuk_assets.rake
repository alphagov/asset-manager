require 'asset_processor'

# rubocop:disable Metrics/BlockLength
namespace :govuk_assets do
  desc 'Store values generated from file metadata for all GOV.UK assets'
  task store_values_generated_from_file_metadata: :environment do
    processor = AssetProcessor.new
    processor.process_all_assets_with do |asset_id|
      AssetFileMetadataWorker.perform_async(asset_id)
    end
  end
end
# rubocop:enable Metrics/BlockLength
