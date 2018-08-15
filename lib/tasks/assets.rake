namespace :assets do
  desc "Mark an asset as deleted and remove from S3"
  task :delete_and_remove_from_s3, [:id] => :environment do |_t, args|
    asset = Asset.find(args.fetch(:id))
    asset.delete
    Services.cloud_storage.delete(asset)
  end
end
