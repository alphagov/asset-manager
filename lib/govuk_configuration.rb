class GovukConfiguration
  def initialize(env = ENV)
    @env = env
  end

  def app_host
    app_name = @env.fetch('GOVUK_APP_NAME')
    app_domain = @env.fetch('GOVUK_APP_DOMAIN')
    AssetManager.app_host = "http://#{app_name}.#{app_domain}"
  rescue KeyError
    AssetManager.app_host = 'http://localhost:3000'
  end
end
