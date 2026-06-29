require "services"

class SvgScanBulkJob
  include Sidekiq::Job

  sidekiq_options lock: :until_executing, queue: "low_priority"

  def perform(asset_id)
    asset = Asset.find(asset_id)

    begin
      file = Services.cloud_storage.download(asset)
    rescue Aws::S3::Errors::NoSuchKey
      # File doesn't exist in S3. Nothing to do.
      return
    end

    begin
      if Marcel::MimeType.for(Pathname.new(file.path)) == "image/svg+xml"
        begin
          Rails.logger.info("#{asset_id} - SvgScanBulkJob#perform - SVG scan started")
          Services.svg_scanner.scan(file.path)
        rescue SvgDocument::UnsafeSvg => e
          Rails.logger.info("#{asset_id} - SvgScanBulkJob#perform - SVG unsafe")
          GovukError.notify(e, extra: { id: asset.id, filename: asset.filename })
        end
      end
    ensure
      unless file.nil?
        file.close
        file.unlink
      end
    end
  end
end
