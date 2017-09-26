require 'virus_scanner'

class VirusScanWorker
  include Sidekiq::Worker

  def perform(asset_id)
    asset = Asset.find(asset_id)
    scanner = VirusScanner.new(asset.file.current_path)
    if scanner.clean?
      asset.scanned_clean
    else
      Airbrake.notify_or_ignore(VirusScanner::InfectedFile.new, error_message: scanner.virus_info, params: { id: asset.id, filename: asset.filename })
      asset.scanned_infected
    end
  end
end
