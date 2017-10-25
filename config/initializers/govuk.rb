begin
  app_name = ENV.fetch('GOVUK_APP_NAME')
  app_domain = ENV.fetch('GOVUK_APP_DOMAIN')
  AssetManager.app_host = "http://#{app_name}.#{app_domain}"
rescue KeyError
  AssetManager.app_host = 'http://localhost:3000'
end
