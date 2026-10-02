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

  desc "Scan a batch of files yet to be scanned for SVG vulnerabilites"
  task :bulk_scan_svgs, %i[batch_size] => :environment do |_t, args|
    if Sidekiq::Queue.new("batch").any?
      message = "Not enqueuing assets for bulk SVG scanning: previous batch still in progress"
      Rails.logger.info(message)
      puts message

      next
    end

    batch_size = args.fetch(:batch_size, nil)&.to_i

    unless batch_size&.positive?
      raise ArgumentError, "Invalid batch size for bulk SVG scanning: #{batch_size.inspect}"
    end

    message = "Enqueuing up to #{batch_size} assets for bulk SVG scanning"
    Rails.logger.info(message)
    puts message

    scope = Asset
      .where(
        state: "uploaded",
        deleted_at: nil,
        redirect_url: nil,
        svg_scan_state: nil,
        :mime_type.in => [nil, "image/svg+xml"],
      )
      .limit(batch_size)

    raise "No assets found to enqueue for bulk SVG scanning" unless scope.any?

    scope.each(&:schedule_svg_batch_scan)
  end
end
