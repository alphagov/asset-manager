module ApplicationHelper
  def ensure_file_is_same_after_scan(asset, job_name, next_state)
    initial_digest = asset.md5_hexdigest
    Rails.logger.info("#{asset.id} - #{job_name}#perform - scan started")
    yield
    asset.reload.md5_hexdigest == initial_digest ? asset.send(next_state): Rails.logger.info("#{asset.id} #{job_name} checksum failed")
  end
end
