require "services"

module Healthcheck
  class CloudStorage
    def name
      :cloud_storage
    end

    def status
      Services.cloud_storage.healthy? ? GovukHealthcheck::OK : GovukHealthcheck::CRITICAL
    end
  end
end
