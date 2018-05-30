class Healthcheck
  class DatabaseHealthcheck < Base
    def name
      :database
    end

    def status
      Asset.unscoped.count
      :ok
    rescue Mongo::Error::NoServerAvailable
      :critical
    end

    def details
      {}
    end
  end
end
