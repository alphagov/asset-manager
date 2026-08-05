require "services"

class SvgScanBatchJob
  include Sidekiq::Job

  sidekiq_options queue: "batch"

  def perform(asset_id)
    asset = Asset.find(asset_id)
    file = Services.cloud_storage.download(asset)

    ensure_mime_type_set(asset, file.path)

    scan_svg(asset, file.path) if asset.mime_type == "image/svg+xml"
  rescue Aws::S3::Errors::NoSuchKey
    asset.update!(svg_scan_state: "file_missing_from_s3")
    Rails.logger.info("#{asset_id} - SvgScanBatchJob - Asset missing from S3")
  ensure
    if file.respond_to?(:path) && File.exist?(file.path)
      file.close
      file.unlink
    end
  end

private

  def ensure_mime_type_set(asset, file_path)
    if asset.mime_type.nil?
      asset.set(mime_type: Marcel::MimeType.for(Pathname.new(file_path)))
      asset.reload
    end
  end

  def scan_svg(asset, file_path)
    Rails.logger.info("#{asset.id} - SvgScanBatchJob - SVG scan started")
    Services.svg_scanner.scan(file_path)
    asset.update!(svg_scan_state: "svg_clean")
  rescue SvgDocument::UnsafeSvg => e
    asset.update!(svg_scan_state: "svg_infected")
    Rails.logger.info("#{asset.id} - SvgScanBatchJob - SVG unsafe")
    GovukError.notify(e, extra: { id: asset.id, filename: asset.filename })
  ensure
    asset.update!(svg_scanned_at: Time.zone.now)
  end
end
