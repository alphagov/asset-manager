require "asset_processor"

namespace :govuk_assets do
  desc "Delete file from NFS for assets uploaded to S3"
  task delete_file_from_nfs_for_assets_uploaded_to_s3: :environment do
    processor = AssetProcessor.new(scope: Asset.where(state: "uploaded"))
    processor.process_all_assets_with do |asset_id|
      DeleteAssetFileFromNfsWorker.perform_async(asset_id.to_s)
    end
  end

  desc "Normalize blank Asset#redirect_url values"
  task normalize_blank_asset_redirect_url_values: :environment do
    scope = Asset.where(redirect_url: "")
    result = scope.update_all("$unset" => { redirect_url: true })
    status = result.successful? ? "OK" : "Error"
    puts "#{status}: #{result.written_count} documents updated"
  end

  desc "Upload all *.zip files in the given directory to /government/uploads/uploaded/hmrc"
  task :create_hmrc_paye_zips, %i[directory] => :environment do |_, args|
    directory = args[:directory]
    hmrc_url_base = "/government/uploads/uploaded/hmrc"

    Dir.glob(File.join(directory, "*.zip")).each do |file_path|
      WhitehallAsset.create_or_replace(file_path, "#{hmrc_url_base}/#{File.basename(file_path)}")
    end
  end

  desc "Upload a file to /government/uploads/uploaded/hmrc.  The optional second argument is the filename to use."
  task :create_hmrc_paye_asset, %i[file_path] => :environment do |_, args|
    file_path = args[:file_path]

    basename = File.basename(file_path)
    if args.extras.count.positive?
      basename = args.extras[0]
    end

    hmrc_url_base = "/government/uploads/uploaded/hmrc"
    WhitehallAsset.create_or_replace(file_path, "#{hmrc_url_base}/#{basename}")
  end

  desc "Create a whitehall asset with the given legacy URL path"
  task :create_whitehall_asset, %i[file_path legacy_url_path] => :environment do |_, args|
    WhitehallAsset.create_or_replace(args[:file_path], args[:legacy_url_path])
  end
end
