require "services"

class VirusScanJob
  include Sidekiq::Job
  include EnsureFile

  sidekiq_options lock: :until_executing

  def perform(asset_id)
    asset = Asset.find(asset_id)
    if asset.unscanned?
      begin
        file_unchanged = ensure_file_is_same_after_scan(asset) do
          Rails.logger.info("#{asset_id} - VirusScanJob - Virus scan started")
          Services.virus_scanner.scan(asset.file.path)
        end

        if file_unchanged
          asset.virus_scanned_clean!
        else
          Rails.logger.info("#{asset.id} - VirusScanJob - Checksum failed; queueing a new scan")
          asset.schedule_virus_scan
        end
      rescue VirusScanner::InfectedFile
        Rails.logger.warn("#{asset_id} - VirusScanJob - File #{asset.filename} marked as infected")
        asset.virus_scanned_infected!
      rescue VirusScanner::Error
        raise if File.exist?(asset.file.path)

        handle_replaced_file(asset)
      end
    end
  end

private

  def handle_replaced_file(asset)
    reloaded = asset.reload

    if reloaded.unscanned? && File.exist?(reloaded.file.path)
      Rails.logger.warn("#{reloaded.id} - VirusScanJob - File replaced during scan; queueing scan of the current file")
      reloaded.schedule_virus_scan
    else
      Rails.logger.warn("#{reloaded.id} - VirusScanJob - File removed during scan and no new file available to scan")
    end
  end
end
