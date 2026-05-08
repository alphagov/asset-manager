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
        asset.scanned_clean!
      rescue SvgScanner::UnsafeSvgError => e
        GovukError.notify(e, extra: { id: asset.id, filename: asset.filename })
        asset.scanned_svg_unsafe!
      end
    end
  end
end

SvgScanWorker = SvgScanJob
