require "s3_storage"
require "virus_scanner"

module Services
  def self.cloud_storage
    @cloud_storage ||= S3Storage.build
  end

  def self.mimetype_inferrer
    @mimetype_inferrer ||= MimetypeInferrer.new
  end

  def self.svg_scanner
    @svg_scanner ||= SvgScanner.new
  end

  def self.virus_scanner
    @virus_scanner ||= VirusScanner.new
  end
end
