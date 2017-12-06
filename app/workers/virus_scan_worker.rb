require 'virus_scanner'

class VirusScanWorker
  include Sidekiq::Worker

  def perform(asset_id)
    asset = Asset.find(asset_id)
    scanner = VirusScanner.new(asset.file.path)
    if scanner.clean?
      asset.scanned_clean
    else
      GovukError.notify(VirusScanner::InfectedFile.new, extra: { error_message: scanner.virus_info, id: asset.id, filename: asset.filename })
      asset.scanned_infected
    end
  end
end
