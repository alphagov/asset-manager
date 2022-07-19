require "services"

class VirusScanWorker
  include Sidekiq::Worker

  def perform(asset_id)
    asset = Asset.find(asset_id)
    if asset.unscanned?
      begin
        Services.virus_scanner.scan(asset.file.path)
        asset.scanned_clean!
      rescue VirusScanner::InfectedFile => e
        GovukError.notify(e, extra: { id: asset.id, filename: asset.filename })
        asset.scanned_infected!
      rescue StateMachines::InvalidTransition
        # If the asset has been amended whilst virus scanning takes place, the `scanned_clean` method will fail as it will be an invalid transition in state
      end
    end
  end
end
