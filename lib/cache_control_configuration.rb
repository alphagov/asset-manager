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

  def expires_in(max_age)
    self.class.new(@attributes.merge(max_age: max_age))
  end
end
