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

  desc 'Store HMRC PAYE files, from the given directory'
  task :create_hmrc_paye_assets, %i[directory version] => :environment do |_, args|
    directory = args[:directory]
    version_full = args[:version]
    version_short = version_full.split('.')[0]

    hmrc_url_base = '/government/uploads/uploaded/hmrc'

    manifest_basename = "realtimepayetools-update-v#{version_short}.xml"
    manifest_path = File.join(directory, manifest_basename)
    test_manifest_legacy_url_path = "#{hmrc_url_base}/test-#{manifest_basename}"

    [
      'payetools-linux.zip',
      'payetools-osx.zip',
      'payetools-windows.zip',
      "payetools-rti-#{version_full}-linux.zip",
      "payetools-rti-#{version_full}-osx.zip",
      "payetools-rti-#{version_full}-windows.zip",
    ].each do |basename|
      create_or_replace_whitehall_asset(File.join(directory, basename), "#{hmrc_url_base}/#{basename}")
    end

    create_or_replace_whitehall_asset(manifest_path, test_manifest_legacy_url_path)

    puts ''
    puts "If there are any other files to upload, use 'rake govuk_assets:create_whitehall_asset[/path/to/file.ext,#{hmrc_url_base}/file.ext]'."
    puts "Run 'rake govuk_assets:create_whitehall_asset[#{manifest_path},#{hmrc_url_base}/#{manifest_basename}]' to store the file to the real URL after it is confirmed to work."
  end

  desc 'Create a whitehall asset with the given legacy URL path'
  task :create_whitehall_asset, %i[file_path legacy_url_path] => :environment do |_, args|
    create_or_replace_whitehall_asset(args[:file_path], args[:legacy_url_path])
  end
end
