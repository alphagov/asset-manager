require 'services'
require 'asset_processor'

namespace :govuk_assets do
  desc 'Update state for clean assets with S3 object to uploaded'
  task update_state_for_clean_assets_with_s3_object_to_uploaded: :environment do
    processor = AssetProcessor.new(scope: Asset.unscoped.where(state: 'clean'))
    processor.process_all_assets_with do |asset_id|
      AssetUploadStateWorker.perform_async(asset_id)
    end
  end
end
