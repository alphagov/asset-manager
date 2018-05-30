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

  def unreplace_asset(asset)
    if asset.replacement.nil?
      puts "#{asset.uuid} has no replacement"
      return
    end

    puts "found replacement #{asset.replacement.uuid}"

    asset.replacement.update!(deleted: true)
    asset.update!(replacement: nil)
  end

  desc 'Unreplace an asset and delete the replacement'
  task :unreplace_asset, [:uuid] => :environment do |_, args|
    asset = Asset.unscoped.find_by!(uuid: args[:uuid])
    unreplace_asset(asset)
  end

  desc 'Unreplace a Whitehall asset and delete the replacement'
  task :unreplace_whitehall_asset, [:legacy_url_path] => :environment do |_, args|
    asset = WhitehallAsset.unscoped.find_by!(legacy_url_path: args[:legacy_url_path])
    unreplace_asset(asset)
  end
end
