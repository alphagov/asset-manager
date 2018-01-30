require_relative 'boot'

# Pick the frameworks you want:
# require "active_model/railtie"
# require "active_job/railtie"
# require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_view/railtie"
require "sprockets/railtie"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module AssetManager
  class Application < Rails::Application
    config.load_defaults 5.1
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

    config.assets.prefix = '/asset-manager'
  end

  mattr_accessor :govuk

  mattr_accessor :s3

  mattr_accessor :carrier_wave_store_base_dir

  mattr_accessor :cache_control
  mattr_accessor :whitehall_cache_control
  mattr_accessor :content_disposition
  mattr_accessor :default_content_type
  mattr_accessor :frame_options
  mattr_accessor :whitehall_frame_options

  mattr_accessor :fake_s3
end
