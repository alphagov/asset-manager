require "s3_storage"
require "virus_scanner"

module Services
  def self.cloud_storage
    @cloud_storage ||= S3Storage.build
  end

  def self.virus_scanner
    @virus_scanner ||= VirusScanner.new
  end
end
