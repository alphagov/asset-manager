require 'services'
require 'asset_processor'

namespace :govuk_assets do
  desc 'Set uploaded state for all clean assets (uploaded/not_uploaded)'
  task set_uploaded_state_for_all_clean_assets: :environment do
    processor = AssetProcessor.new(scope: Asset.where(state: 'clean'))
    processor.process_all_assets_with do |asset_id|
      AssetUploadStateWorker.perform_async(asset_id)
    end
  end
end
