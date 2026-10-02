module EnsureFile
  extend ActiveSupport::Concern

  def ensure_file_is_same_after_scan(asset)
    initial_digest = asset.md5_hexdigest
    yield
    asset.reload.md5_hexdigest == initial_digest
  end
end
