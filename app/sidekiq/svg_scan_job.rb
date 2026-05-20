require "services"

class SvgScanJob
  include Sidekiq::Job

  sidekiq_options lock: :until_and_while_executing

  def perform(asset_id)
    asset = Asset.find(asset_id)
    if asset.unscanned?
      begin
        Rails.logger.info("#{asset_id} - SvgScanJob#perform - SVG scan started")
        Services.svg_scanner.scan(asset.file.path)
        asset.reload.md5_hexdigest == initial_digest ? asset.svg_scanned_clean! : Rails.logger.info("#{asset.id} SvgScanJob checksum failed")
      rescue SvgScanner::UnsafeSvgError => e
        GovukError.notify(e, extra: { id: asset.id, filename: asset.filename })
        asset.scanned_infected!
      end
    end
  end
end

SvgScanWorker = SvgScanJob
