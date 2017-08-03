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

  def header
    response = ActionDispatch::Response.new
    @attributes.each do |key, value|
      response.cache_control[key] = value
    end
    response.prepare!
    response['Cache-Control']
  end
end
