require "services"

class SvgScanBatchJob
  include Sidekiq::Job

  sidekiq_options lock: :until_executing, queue: "batch"

  def perform(asset_id)
    asset = Asset.find(asset_id)

    file = Services.cloud_storage.download(asset)

    if Marcel::MimeType.for(Pathname.new(file.path)) == "image/svg+xml"
      scan_svg(asset, file.path)
    end
  rescue Aws::S3::Errors::NoSuchKey
    # File doesn't exist in S3. Nothing to do.
    Rails.logger.info("#{asset_id} - SvgScanBatchJob#perform - Asset missing from S3")
  ensure
    if file.respond_to?(:path) && File.exist?(file.path)
      file.close
      file.unlink
    end
  end

private

  def scan_svg(asset, file_path)
    Rails.logger.info("#{asset.id} - SvgScanBatchJob#perform - SVG scan started")
    Services.svg_scanner.scan(file_path)
    asset.set(svg_scanned_safe: true)
  rescue SvgDocument::UnsafeSvg => e
    asset.set(svg_scanned_safe: false)
    Rails.logger.info("#{asset.id} - SvgScanBatchJob#perform - SVG unsafe")
    GovukError.notify(e, extra: { id: asset.id, filename: asset.filename })
  ensure
    asset.set(svg_scanned_at: Time.zone.now)
  end
end
