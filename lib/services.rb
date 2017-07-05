require 's3_storage'

module Services
  def self.cloud_storage
    @cloud_storage ||= S3Storage.new
  end
end
