class GovukConfiguration
  def initialize(env = ENV)
    @env = env
  end

  def app_host
    app_name = @env.fetch('GOVUK_APP_NAME')
    app_domain = @env.fetch('GOVUK_APP_DOMAIN')
    "http://#{app_name}.#{app_domain}"
  rescue KeyError
    nil
  end
end
