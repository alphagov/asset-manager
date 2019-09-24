require "open3"

# Simple wrapper around ClamAV
#
# This expects govuk_clamscan to exist on the PATH, and be a symlink
# to either clamscan or clamdscan
class VirusScanner
  class Error < StandardError; end
  class InfectedFile < StandardError; end

  def scan(file_path)
    clamscan_path = AssetManager.govuk.clamscan_path
    out_str, status = Open3.capture2e(clamscan_path, "--no-summary", file_path)
    case status.exitstatus
    when 0
      return true
    when 1
      raise InfectedFile, out_str
    else
      raise Error, out_str
    end
  end
end
