require 'services'

RSpec.configure do |config|
  config.before(:each, disable_cloud_storage_stub: false) do
    cloud_storage = double(:cloud_storage).as_null_object
    allow(Services).to receive(:cloud_storage).and_return(cloud_storage)
  end
end
