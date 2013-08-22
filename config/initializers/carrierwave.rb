CarrierWave.configure do |config|
  config.fog_credentials = {
    :provider           => 'Rackspace',
    :rackspace_username => ENV['RACKSPACE_USERNAME'],
    :rackspace_api_key  => ENV['RACKSPACE_API_KEY'],
    :rackspace_auth_url => ENV['RACKSPACE_API_ENDPOINT']
  }
  config.fog_directory = ENV['QUIRKAFLEEG_ASSET_MANAGER_RACKSPACE_CONTAINER']
end