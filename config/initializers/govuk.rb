require 'govuk_configuration'

config = GovukConfiguration.new
AssetManager.app_host = config.app_host
