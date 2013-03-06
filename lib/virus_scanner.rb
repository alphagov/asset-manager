require 'open3'

# Simple wrapper around ClamAV
#
# This expects govuk_clamscan to exist on the PATH, and be a symlink
# to either clamscan or clamdscan
class VirusScanner
  class Error < StandardError; end

  def initialize(file_path)
    @file_path = file_path
    @scanned = false
  end

  def clean?
    scan unless @scanned
    @clean
  end

  private

  def scan
    out_str, status = Open3.capture2e('govuk_clamscan', '--no-summary', @file_path)
    case status.exitstatus
    when 0
      @clean = true
    when 1
      @clean = false
      @virus_info = out_str
    else
      raise Error.new(out_str)
    end
    @scanned = true
  rescue SystemCallError => e
    raise Error.new(e)
  end
end
