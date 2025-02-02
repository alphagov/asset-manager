require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
# require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module AssetManager
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    # This app frequently redirects to different hosts (GOV.UK redirects,
    # between draft and live hosts).
    config.action_controller.raise_on_open_redirects = false

    # Disable Rack::Cache
    config.action_dispatch.rack_cache = nil

    # ActionDispatch strict freshness
    #
    # Configures whether the ActionDispatch::ETag middleware should prefer the
    # ETag header over the Last-Modified header when both are present in the
    # response.
    #
    # If set to true, when both headers are present only the ETag is considered
    # as specified by RFC 7232 section 6.
    #
    # If set to false, when both headers are present, both headers are checked
    # and both need to match for the response to be considered fresh.
    config.action_dispatch.strict_freshness = false

    config.assets.prefix = "/asset-manager"

    unless Rails.application.config_for(:secrets).jwt_auth_secret
      raise "JWT auth secret is not configured. See config/secrets.yml"
    end
  end

  mattr_accessor :govuk

  mattr_accessor :s3

  mattr_accessor :carrier_wave_store_base_dir

  mattr_accessor :content_disposition
  mattr_accessor :default_content_type

  mattr_accessor :fake_s3
end
