module EnsureFile
  extend ActiveSupport::Concern

  def ensure_file_is_same_after_scan(asset, job_name, success_callback)
    initial_digest = asset.md5_hexdigest
    Rails.logger.info("#{asset.id} - #{job_name}#perform - scan started")
    yield
    if asset.reload.md5_hexdigest == initial_digest
      success_callback.call
    else
      Rails.logger.info("#{asset.id} #{job_name} checksum failed")
    end
  end
end
