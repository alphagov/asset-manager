require "services"

class VirusScanJob
  include Sidekiq::Job

  sidekiq_options lock: :until_and_while_executing

  def perform(asset_id)
    asset = Asset.find(asset_id)
    if asset.unscanned?
      begin
        Rails.logger.info("#{asset_id} - VirusScanJob#perform - Virus scan started")
        Services.virus_scanner.scan(asset.file.path)
        asset.scanned_clean!
      rescue VirusScanner::InfectedFile => e
        GovukError.notify(e, extra: { id: asset.id, filename: asset.filename })
        asset.scanned_infected!
      end
    end
  end
end
