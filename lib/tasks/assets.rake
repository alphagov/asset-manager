namespace :assets do
  desc "Mark an asset as deleted and (optionally) remove from S3"
  task :delete, %i[id permanent] => :environment do |_t, args|
    asset = Asset.find(args.fetch(:id))
    asset.destroy!
    Services.cloud_storage.delete(asset) if args[:permanent]
  end

  desc "Mark a Whitehall asset as deleted and (optionally) remove from S3"
  task :whitehall_delete, %i[legacy_url_path permanent] => :environment do |_t, args|
    asset = WhitehallAsset.find_by!(legacy_url_path: args.fetch(:legacy_url_path))
    Rake::Task["assets:delete"].invoke(asset.id, args[:permanent])
  end

  desc "Mark an asset as a redirect"
  task :redirect, %i[id redirect_url] => :environment do |_t, args|
    asset = Asset.find(args.fetch(:id))
    redirect_url = args.fetch(:redirect_url)
    abort "redirect_url must start with https://" unless redirect_url.start_with? "https://"
    asset.update!(redirect_url:, deleted_at: nil)
  end

  desc "Mark a Whitehall asset as a redirect"
  task :whitehall_redirect, %i[legacy_url_path redirect_url] => :environment do |_t, args|
    asset = WhitehallAsset.find_by!(legacy_url_path: args.fetch(:legacy_url_path))
    Rake::Task["assets:redirect"].invoke(asset.id, args.fetch(:redirect_url))
  end

  desc "Get a Whitehall asset's ID by its legacy_url_path, e.g. /government/uploads/system/uploads/attachment_data/file/1234/document.pdf"
  task :get_id_by_legacy_url_path, %i[legacy_url_path] => :environment do |_t, args|
    legacy_url_path = args.fetch(:legacy_url_path)
    asset = WhitehallAsset.find_by!(legacy_url_path:)
    puts "Asset ID for #{legacy_url_path} is #{asset.id}."
  end

  desc "Soft delete assets and check deleted invalid state"
  task :bulk_soft_delete, %i[csv_path] => :environment do |_t, args|
    csv_path = args.fetch(:csv_path)

    CSV.foreach(csv_path, headers: false) do |row|
      asset_id = row[0]
      asset = Asset.find(asset_id)
      asset.state = "uploaded" if asset.state == "deleted"

      begin
        asset.destroy!
        print "."
      rescue Mongoid::Errors::Validations
        puts "Failed to delete asset of ID #{asset_id}: #{asset.errors.full_messages}"
      end
    end
  end
end
