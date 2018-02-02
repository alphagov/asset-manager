require 'services'

class VirusScanWorker
  include Sidekiq::Worker

  def perform(asset_id)
    asset = Asset.find(asset_id)
    begin
      Services.virus_scanner.scan(asset.file.path)
      asset.scanned_clean!
    rescue VirusScanner::InfectedFile => e
      GovukError.notify(e, extra: { id: asset.id, filename: asset.filename })
      asset.scanned_infected!
    end
  end
end
