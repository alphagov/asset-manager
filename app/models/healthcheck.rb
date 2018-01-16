class Healthcheck
  class Base
    def name
      raise NotImplemented
    end

    def status
      raise NotImplemented
    end

    def details
      raise NotImplemented
    end
  end

  def self.build
    new([
      DatabaseHealthcheck.new,
      RedisHealthcheck.new,
    ])
  end

  def initialize(healthchecks = [])
    @healthchecks = healthchecks
  end

  def status
    if statuses.include?(:critical)
      :critical
    elsif statuses.include?(:warning)
      :warning
    else
      :ok
    end
  end

  def details
    { checks: checks }
  end

private

  def checks
    @healthchecks.each.with_object({}) do |check, hash|
      hash[check.name] = check.details.merge(status: check.status)
    end
  end

  def statuses
    @statuses ||= @healthchecks.map(&:status)
  end
end
