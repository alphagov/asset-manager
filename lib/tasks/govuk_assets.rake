require 'asset_processor'

namespace :govuk_assets do
  desc 'Delete file from NFS for assets uploaded to S3'
  task delete_file_from_nfs_for_assets_uploaded_to_s3: :environment do
    processor = AssetProcessor.new(scope: Asset.where(state: 'uploaded'))
    processor.process_all_assets_with do |asset_id|
      DeleteAssetFileFromNfsWorker.perform_async(asset_id)
    end
  end

  desc 'Normalize blank Asset#redirect_url values'
  task normalize_blank_asset_redirect_url_values: :environment do
    scope = Asset.where(redirect_url: '')
    result = scope.update_all('$unset' => { redirect_url: true })
    status = result.successful? ? 'OK' : 'Error'
    puts "#{status}: #{result.written_count} documents updated"
  end

  def create_or_replace_whitehall_asset(file_path, legacy_url_path)
    begin
      prior = WhitehallAsset.find_by(legacy_url_path: legacy_url_path)
      prior.file = Pathname.new(file_path).open
      prior.save!
    rescue Mongoid::Errors::DocumentNotFound
      WhitehallAsset.create!(
        file: Pathname.new(file_path).open,
        legacy_url_path: legacy_url_path,
      )
    end
    puts "Uploaded '#{file_path}' to '#{legacy_url_path}'"
  end

  desc 'Upload a file to /government/uploads/uploaded/hmrc.  The optional second argument is the filename to use.'
  task :create_hmrc_paye_asset, %i[file_path] => :environment do |_, args|
    hmrc_url_base = '/government/uploads/uploaded/hmrc'

    file_path = args[:file_path]

    basename = File.basename(file_path)
    if args.extras.count.positive?
      basename = args.extras[0]
    end

    create_or_replace_whitehall_asset(file_path, "#{hmrc_url_base}/#{basename}")
  end

  desc 'Create a whitehall asset with the given legacy URL path'
  task :create_whitehall_asset, %i[file_path legacy_url_path] => :environment do |_, args|
    create_or_replace_whitehall_asset(args[:file_path], args[:legacy_url_path])
  end
end
