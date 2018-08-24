namespace :assets do
  desc "Mark an asset as deleted"
  task :delete, [:id] => :environment do |_t, args|
    Asset.find(args.fetch(:id)).destroy
  end

  desc "Restore an asset after being deleted"
  task :restore, [:id] => :environment do |_t, args|
    Asset.find(args.fetch(:id)).restore
  end

  desc "Mark an asset as deleted and remove from S3"
  task :delete_and_remove_from_s3, [:id] => :environment do |_t, args|
    asset = Asset.find(args.fetch(:id))
    asset.destroy
    Services.cloud_storage.delete(asset)
  end
end
