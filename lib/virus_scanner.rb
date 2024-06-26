require "open3"

# Simple wrapper around ClamAV
#
# This expects AssetManager.govuk.clamscan_path to be an executable command
# that is compatible with clamscan or clamdscan.
class VirusScanner
  class Error < StandardError; end

  class InfectedFile < StandardError; end

  def scan(file_path)
    clamscan_path = AssetManager.govuk.clamscan_path
    out_str, status = Open3.capture2e(clamscan_path, "--no-summary", file_path)
    case status.exitstatus
    when 0
      true
    when 1
      raise InfectedFile, out_str
    else
      raise Error, out_str
    end
  end
end
