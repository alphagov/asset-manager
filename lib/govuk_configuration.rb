class GovukConfiguration
  def initialize(env = ENV, plek = Plek)
    @env = env
    @plek = plek
  end

  def app_host
    app_name = @env.fetch("GOVUK_APP_NAME")
    app_domain = @env.fetch("GOVUK_APP_DOMAIN")
    "http://#{app_name}.#{app_domain}"
  rescue KeyError
    nil
  end

  def assets_host
    assets_base_uri = @plek.external_url_for("assets")
    URI.parse(assets_base_uri).host
  end

  def draft_assets_host
    draft_assets_base_uri = @plek.external_url_for("draft-assets")
    URI.parse(draft_assets_base_uri).host
  end

  def clamscan_path
    @env.fetch("ASSET_MANAGER_CLAMSCAN_PATH", "govuk_clamscan")
  end
end
