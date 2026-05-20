require "services"

class VirusScanJob
  include Sidekiq::Job
  include EnsureFile

  sidekiq_options lock: :until_executing

  class AssetReplaced < StandardError; end

  def perform(asset_id)
    asset = Asset.find(asset_id)
    if asset.unscanned?
      begin
        Rails.logger.info("#{asset_id} - VirusScanJob#perform - Virus scan started")
        ensure_file_is_same_after_scan(asset, "VirusScanJob", :virus_scanned_clean!) do
          Services.virus_scanner.scan(asset.file.path)
        end
      rescue VirusScanner::InfectedFile => e
        GovukError.notify(e, extra: { id: asset.id, filename: asset.filename })
        asset.scanned_infected!
      end
    end
  end
end
