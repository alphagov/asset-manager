require 'asset_processor'

namespace :govuk_assets do
  desc 'Delete file from NFS for assets uploaded to S3'
  task delete_file_from_nfs_for_assets_uploaded_to_s3: :environment do
    processor = AssetProcessor.new(scope: Asset.unscoped.where(state: 'uploaded'))
    processor.process_all_assets_with do |asset_id|
      DeleteAssetFileFromNfsWorker.perform_async(asset_id)
    end
  end
end
