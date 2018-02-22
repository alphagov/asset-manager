require 'asset_processor'

namespace :govuk_assets do
  desc 'Delete file from NFS for assets uploaded to S3'
  task delete_file_from_nfs_for_assets_uploaded_to_s3: :environment do
    processor = AssetProcessor.new(scope: Asset.unscoped.where(state: 'uploaded'))
    processor.process_all_assets_with do |asset_id|
      DeleteAssetFileFromNfsWorker.perform_async(asset_id)
    end
  end

  desc 'Normalize blank Asset#redirect_url values'
  task normalize_blank_asset_redirect_url_values: :environment do
    scope = Asset.unscoped.where(redirect_url: '')
    result = scope.update_all('$unset' => { redirect_url: true })
    status = result.successful? ? 'OK' : 'Error'
    puts "#{status}: #{result.written_count} documents updated"
  end
end
