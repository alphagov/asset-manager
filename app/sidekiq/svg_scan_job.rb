require "services"

class SvgScanJob
  include Sidekiq::Job
  include EnsureFile

  sidekiq_options lock: :until_executing

  def perform(asset_id)
    asset = Asset.find(asset_id)
    if asset.virus_scanned_clean?
      begin
        Rails.logger.info("#{asset_id} - SvgScanJob#perform - SVG scan started")
        ensure_file_is_same_after_scan(asset, "SvgScanJob", -> { asset.svg_scanned_clean! }) do
          Services.svg_scanner.scan(asset.file.path)
        end
      rescue SvgDocument::UnsafeSvg
        asset.svg_scanned_infected!
      end
    end
  end
end
