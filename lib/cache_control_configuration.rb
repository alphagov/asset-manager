class CacheControlConfiguration
  def initialize(attributes = {})
    @attributes = attributes
  end

  def max_age
    @attributes[:max_age]
  end

  def options
    @attributes.except(:max_age)
  end
end
