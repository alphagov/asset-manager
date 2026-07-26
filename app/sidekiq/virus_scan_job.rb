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
        ensure_file_is_same_after_scan(asset, "VirusScanJob", :virus_scanned_clean!) do
          Rails.logger.info("#{asset_id} - VirusScanJob#perform - Virus scan started")
          Services.virus_scanner.scan(asset.file.path)
        end
      rescue VirusScanner::InfectedFile
        Rails.logger.warn("#{asset_id} - VirusScanJob#perform - File #{asset.filename} marked as infected")
        asset.virus_scanned_infected!
      end
    end
  end
end
