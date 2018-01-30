class GovukConfiguration
  def initialize(env = ENV, plek = Plek.new)
    @env = env
    @plek = plek
  end

  def app_host
    app_name = @env.fetch('GOVUK_APP_NAME')
    app_domain = @env.fetch('GOVUK_APP_DOMAIN')
    "http://#{app_name}.#{app_domain}"
  rescue KeyError
    nil
  end

  def draft_assets_host
    draft_assets_base_uri = @plek.external_url_for('draft-assets')
    URI.parse(draft_assets_base_uri).host
  end
end
