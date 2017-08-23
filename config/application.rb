require File.expand_path('../boot', __FILE__)

# Pick the frameworks you want:
# require "active_model/railtie"
# require "active_job/railtie"
# require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_view/railtie"
# require "sprockets/railtie"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module AssetManager
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Disable Rack::Cache
    config.action_dispatch.rack_cache = nil

    config.action_dispatch.x_sendfile_header = "X-Accel-Redirect"
  end

  mattr_accessor :aws_s3_bucket_name
  mattr_accessor :aws_s3_use_virtual_host

  mattr_accessor :proxy_all_asset_requests_to_s3_via_rails
  mattr_accessor :proxy_all_asset_requests_to_s3_via_nginx
  mattr_accessor :redirect_all_asset_requests_to_s3

  mattr_accessor :cache_control
  mattr_accessor :content_disposition
  mattr_accessor :default_content_type
end
