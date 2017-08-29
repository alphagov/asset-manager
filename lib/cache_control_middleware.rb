class CacheControlMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    if headers['X-Accel-ETag'].present?
      headers.delete('Cache-Control')
    end
    [status, headers, body]
  end
end
