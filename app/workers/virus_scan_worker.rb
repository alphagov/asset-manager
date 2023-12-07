require "services"

class VirusScanWorker
  include Sidekiq::Worker

  sidekiq_options lock: :until_and_while_executing

  def perform(asset_id)
    asset = Asset.find(asset_id)
    if asset.unscanned?
      begin
        Rails.logger.info("#{asset_id} - VirusScanWorker#perform - Virus scan started")
        Services.virus_scanner.scan(asset.file.path)
        # This is to deal with a concurrency issue in production
        # It looks like sometimes VirusScannerWorker can be scheduled several times for one file
        # And the other process might change the state already of as the virus scan take time
        # This if condition is to avoid unnecessary state transitions and therefore other
        # concurrency issues
        asset.scanned_clean! if Asset.find(asset_id).unscanned?
      rescue VirusScanner::InfectedFile => e
        GovukError.notify(e, extra: { id: asset.id, filename: asset.filename })
        asset.scanned_infected!
      end
    end
  end
end
