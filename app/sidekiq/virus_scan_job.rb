require "services"

class VirusScanJob
  include Sidekiq::Job

  sidekiq_options lock: :until_and_while_executing

  def perform(asset_id)
    asset = Asset.find(asset_id)
    initial_digest = asset.md5_hexdigest
    if asset.unscanned?
      begin
        asset.begun_scan!
        Rails.logger.info("#{asset_id} - VirusScanJob#perform - Virus scan started")
        Services.virus_scanner.scan(asset.file.path)
        asset.scanned_clean! if asset.reload.md5_hexdigest == initial_digest
      rescue VirusScanner::InfectedFile => e
        GovukError.notify(e, extra: { id: asset.id, filename: asset.filename })
        asset.scanned_infected!
      end
    end
  end
end

VirusScanWorker = VirusScanJob
