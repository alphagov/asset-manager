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
    asset.update!(redirect_url: redirect_url, deleted_at: nil)
  end

  desc "Mark a Whitehall asset as a redirect"
  task :whitehall_redirect, %i[legacy_url_path redirect_url] => :environment do |_t, args|
    asset = WhitehallAsset.find_by!(legacy_url_path: args.fetch(:legacy_url_path))
    Rake::Task["assets:redirect"].invoke(asset.id, args.fetch(:redirect_url))
  end

  desc "Update a Whitehall asset legacy url path for a topical event featuring image"
  task update_topical_event_legacy_url_paths: :environment do |_t|
    legacy_urls_to_update = WhitehallAsset.where("legacy_url_path": /\/government\/uploads\/system\/uploads\/classification_featuring_image_data/).pluck(:legacy_url_path)

    total = legacy_urls_to_update.size
    puts "updating #{legacy_urls_to_update.size} assets"
    legacy_urls_to_update.each_with_index do |legacy_url, index|
      if (index % 1000).zero?
        puts "#{index}/#{total} completed"
      end
      new_url = legacy_url.gsub(/\/classification_featuring_image_data/, "/topical_event_featuring_image_data")
      WhitehallAsset
        .where(legacy_url_path: legacy_url)
        .update_all({ "$set" => { legacy_url_path: new_url } })
    end
  end
end
