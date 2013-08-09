GDS::SSO.config do |config|
  config.user_model   = 'User'

  config.oauth_id     = ENV['ASSET_MANAGER_OAUTH_ID'] || 'abcdefghjasndjkasndassetmanager'
  config.oauth_secret = ENV['ASSET_MANAGER_OAUTH_SECRET'] || 'secret'

  config.oauth_root_url = Plek.current.find("signon")
end
