class Healthcheck
  class RedisHealthcheck < Base
    def name
      :redis
    end

    def status
      Sidekiq.redis_info ? :ok : :critical
    end

    def details
      {}
    end
  end
end
