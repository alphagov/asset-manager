namespace :assets do
  desc "Mark an asset as deleted and remove from S3"
  task :delete_and_remove_from_s3, [:id] => :environment do |_t, args|
    asset = Asset.find(args.fetch(:id))
    asset.destroy
    Services.cloud_storage.delete(asset)
  end

  desc "Mark a Whitehall asset as deleted and remove from S3"
  task :whitehall_delete_and_remove_from_s3, [:legacy_url_path] => :environment do |_t, args|
    asset = WhitehallAsset.find_by(legacy_url_path: args.fetch(:legacy_url_path))
    Rake::Task["assets:delete_and_remove_from_s3"].invoke(asset.id)
  end
end
