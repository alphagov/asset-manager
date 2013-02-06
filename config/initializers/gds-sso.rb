GDS::SSO.config do |config|
  config.user_model   = 'ReadOnlyUser'

  # set up ID and Secret in a way which doesn't require it to be checked in to source control...
  config.oauth_id     = ENV['OAUTH_ID']
  config.oauth_secret = ENV['OAUTH_SECRET']

  # optional config for location of signonotron2
  config.oauth_root_url = "http://localhost:3001"

  # optional config for API Access (requests which accept application/json)
  config.basic_auth_user = 'api'
  config.basic_auth_password = 'secret'
end
