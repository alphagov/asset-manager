require 'cache_control_configuration'

AssetManager.cache_control = CacheControlConfiguration.new(
  max_age: 24.hours,
  public: true
)

AssetManager.whitehall_cache_control = CacheControlConfiguration.new(
  max_age: 24.hours,
  public: true
)
