namespace :assets do
  desc "Mark an asset as deleted and (optionally) remove from S3"
  task :delete, %i[id permanent] => :environment do |_t, args|
    asset = Asset.find(args.fetch(:id))
    asset.destroy
    Services.cloud_storage.delete(asset) if args[:permanent]
  end

  desc "Mark a Whitehall asset as deleted and (optionally) remove from S3"
  task :whitehall_delete, %i[legacy_url_path permanent] => :environment do |_t, args|
    asset = WhitehallAsset.find_by(legacy_url_path: args.fetch(:legacy_url_path))
    Rake::Task["assets:delete"].invoke(asset.id, args[:permanent])
  end
end
