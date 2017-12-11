class GovukConfiguration
  def initialize(env = ENV)
    @env = env
  end

  def app_host
    app_name = @env.fetch('GOVUK_APP_NAME', nil)
    app_domain = @env.fetch('GOVUK_APP_DOMAIN', nil)
    if app_name && app_domain
      "http://#{app_name}.#{app_domain}"
    elsif app_domain
      "http://#{app_domain}"
    else
      "http://localhost:3000"
    end
  end
end
