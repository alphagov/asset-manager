module EnsureFile
  extend ActiveSupport::Concern

  def ensure_file_is_same_after_scan(asset, job_name, next_state)
    initial_digest = asset.md5_hexdigest
    Rails.logger.info("#{asset.id} - #{job_name}#perform - scan started")
    yield
    if asset.reload.md5_hexdigest == initial_digest
      asset.send(next_state)
      asset.set(svg_scanned_safe: true)
      asset.set(svg_scanned_at: Time.zone.now)
    else
      Rails.logger.info("#{asset.id} #{job_name} checksum failed")
    end
  end
end
