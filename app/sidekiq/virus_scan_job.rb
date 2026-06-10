require "services"

class VirusScanJob
  include Sidekiq::Job

  sidekiq_options lock: :until_executing

  class AssetReplaced < StandardError; end

  def perform(asset_id)
    asset = Asset.find(asset_id)
    if asset.unscanned?
      begin
        initial_digest = asset.md5_hexdigest
        Rails.logger.info("#{asset_id} - VirusScanJob#perform - Virus scan started")
        Services.virus_scanner.scan(asset.file.path)
        asset.reload.md5_hexdigest == initial_digest ? asset.scanned_clean! : Rails.logger.info("#{asset.id} VirusScanJob checksum failed")
      rescue VirusScanner::InfectedFile => e
        GovukError.notify(e, extra: { id: asset.id, filename: asset.filename })
        asset.scanned_infected!
      end
    end
  end
end
