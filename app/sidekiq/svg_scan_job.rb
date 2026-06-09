require "services"

class SvgScanJob
  include ApplicationHelper
  include Sidekiq::Job

  sidekiq_options lock: :until_executing

  def perform(asset_id)
    asset = Asset.find(asset_id)
    begin
      Rails.logger.info("#{asset_id} - SvgScanJob#perform - SVG scan started")
      ensure_file_is_same_after_scan(asset, "SvgScanJob", :svg_scanned_clean!) do
        Services.svg_scanner.scan(asset.file.path)
      end
    rescue SvgScanner::UnsafeSvg => e
      Rails.logger.info("#{asset_id} - SvgScanJob#perform - SVG unsafe")
      asset.scanned_infected!
    end
  end
end

SvgScanWorker = SvgScanJob
